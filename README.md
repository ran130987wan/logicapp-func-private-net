# logicapp-func-private-net
# Logic Apps + Azure Function (Flex Consumption) with Private Networking — Beginner End‑to‑End Guide

> Audience: someone new to Azure Functions, Logic Apps, Terraform, and GitHub
> Actions who wants to build the whole thing in their **personal Azure
> subscription first**, then graduate it into this repo's conventions.
>
> Goal: a set of **Logic App schedules** that fire on a timer and call a
> **single HTTP‑triggered C# Azure Function** (on a **Flex Consumption** plan),
> which then talks to a backend over a **private network**.
>
> This guide is intentionally verbose. Skip sections you already know.

## POC Requirement (Authoritative)

- The current POC target is private-oriented infrastructure defaults.
- Terraform execution should use `infra/environments/dev/terraform.private.tfvars`.
- Function public inbound access should remain disabled by default in infra deployment workflows.
- Scheduler behavior requirement stays unchanged: one Function endpoint must handle three scheduled Logic App invocations.
- Current Terraform scheduler resource is Consumption Logic App (`azurerm_logic_app_workflow`); full private Logic App inbound path requires migration to Logic App Standard + VNet integration.
- Cost profile for this POC is intentionally lean: conservative Function scale cap, minimum supported monitoring retention, and no premium service tiers by default.

## Repository Structure

- infra/ : Terraform root and Azure resource definitions.
- infra/environments/ : per-environment tfvars files (for example dev/prod).
- src/MaintenanceApp/ : C# Azure Function source code.
- development/ : local scripts and development environment templates.
- .github/workflows/ : CI/CD automation for Terraform and function deployment.
- .github/agents/, .github/skills/, .github/prompts/, .github/tools/ : GitHub Copilot and automation helpers.
- .github/AGENTS.md : orchestration map for multi-agent POC execution.
- docs/STRUCTURE.md : concise architecture and folder map.

## Codespaces POC Execution (Linux)

Validated on Linux Codespaces (`x86_64`, Ubuntu).

Installed toolchain versions:

- Azure CLI: `2.87.0`
- Terraform: `1.15.6`
- .NET SDK: `10.0.200` (build target remains `net8.0`)
- Azure Functions Core Tools: `4.12.0`

Run sequence used in this repository:

```bash
# 1) Install dependencies if missing (already done in this POC)
sudo apt-get update -y
sudo apt-get install -y azure-cli terraform
sudo npm i -g azure-functions-core-tools@4 --unsafe-perm true

# 2) Bootstrap + validation
./development/scripts/bootstrap.sh

# 3) Build function app
dotnet build src/MaintenanceApp/MaintenanceApp.csproj -c Release

# 4) Login before real plan/apply
az login --tenant b52aa991-8ac7-4b6c-8bc9-03fb21d0d4ac
az account set --subscription cf83455a-73e2-41b7-b28b-fbbf1467713d
terraform -chdir=infra plan -var-file=environments/dev/terraform.private.tfvars
```

Notes:

- `bootstrap.sh` now skips `terraform plan` when `az login` is not present.
- `infra/environments/dev/terraform.private.tfvars` is the default private profile for this POC.
- In Codespaces with multiple dotnet installs, prefer `/usr/bin` runtime path for net8 function hosting.

## Governance and Policy

- Governance baseline is defined in docs/GOVERNANCE.md.
- Terraform apply is approval-gated (never automatic).
- No secrets are committed to repository files.
- Execution uses stage checkpoints: bootstrap, function build, infra validate, infra plan.
- Governance controls can be validated with development/scripts/verify-governance.sh.
- Repository branch protection automation is available via development/scripts/fix-repo-access.sh.
- For private repositories, branch protection requires GitHub Pro; on free plans, make the repository public before running `development/scripts/fix-repo-access.sh`.

## Agent Memory Conventions

- Repository-scoped memory lives in /memories/repo/ and stores stable execution facts for this POC.
- Agents should prefer updating existing memory notes before creating new memory files.
- Keep memory notes short and factual (tool versions, known blockers, required commands).
- Session-specific temporary notes belong in /memories/session/.

## Tested POC: Single Function Triggered 3 Times

Requirement: one Azure Function endpoint must be triggered multiple times by Logic Apps schedules.

Implemented baseline:

- 3 scheduler entries in infra/environments/dev/terraform.tfvars
- 3 Logic App workflows (one per schedule) POST to same function endpoint
- shared function route: /api/jobs/execute

Local test script:

```bash
./development/scripts/test-three-schedules.sh
```

This script validates three scheduler-style invocations against one function endpoint.

Automated PR enforcement:

- .github/workflows/poc-three-trigger.yml runs the same behavior check in CI.

Validated result in this POC run:

- UpcomingExpiredPrograms: Success
- WeeklyExpiredCleanup: Success
- HourlyReconciliation: Success
- Final status: PASS

---

## 0. Review of the architecture you proposed

Your write‑up ("Logic Apps Orchestrated Worker") is a **good, industry‑standard
pattern**, and Flex Consumption is the right plan. A few corrections and
clarifications before you build — these matter and will save you hours:

### 0.1 What "private network" actually means here — read this first

There are **two different network directions**, and they are configured
separately. Beginners conflate them constantly:

| Direction | What it is | How it's done | Affects |
|-----------|-----------|---------------|---------|
| **Outbound** (Function → CP backend) | Function reaches a private backend/DB/API | **VNet integration** — Function joins a delegated subnet | Function → your private services |
| **Inbound** (Logic App → Function) | Who can *call* the function's HTTPS endpoint | **Private endpoint** + `public_network_access_enabled = false`, OR access keys / Entra ID over the public endpoint | Logic App → Function |

Your ASCII diagram shows **outbound** private (Function → CP backend via Private
Link) and **inbound** over public HTTPS secured by keys. **That combination is
valid and is the simplest thing that works.** Keep that for your personal trial.

### 0.2 The trap: "fully private inbound" breaks a Consumption Logic App

If you go further and lock the **inbound** side down (private endpoint on the
function **and** `public_network_access_enabled = false`), then:

- A **Consumption** Logic App **cannot reach the function** — Consumption Logic
  Apps have no VNet integration (the old ISE that allowed it is **retired**).
- To call a private‑endpoint‑only function you must use **Logic Apps Standard**
  with **VNet integration**, so the Logic App sits inside the VNet too.

So pick one of two designs up front:

| Design | Inbound to Function | Logic App SKU | Complexity | Use when |
|--------|--------------------|---------------|------------|----------|
| **A — Public inbound, private outbound** *(start here)* | Public endpoint + Function key / Entra ID | **Consumption** | Low | Personal trial, Q3 planning MVP |
| **B — Fully private** | Private endpoint, public disabled | **Standard** (VNet‑integrated) | High | Hardened production |

This guide builds **Design A** end to end (matches your diagram), then tells you
exactly what changes for Design B.

### 0.3 Other corrections to the snippet you pasted

- **Auth:** Prefer **Entra ID (managed identity)** over `x-functions-key` for
  the Logic App → Function call. Keys are fine for a personal trial; this guide
  shows keys first, then the managed‑identity upgrade.
- **Runtime model:** Your C# uses the **isolated worker** model
  (`Microsoft.Azure.Functions.Worker`) — correct, Flex Consumption **only**
  supports isolated worker. But returning `IActionResult` additionally requires
  the **ASP.NET Core integration** NuGet package
  (`Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore`). Don't forget it.
- **11 schedules:** With **Consumption** Logic Apps you get **one workflow per
  resource**, so 11 schedules = 11 Logic App resources. With **Standard** you
  get **many workflows in one app** (one app, 11 workflows) — cheaper and
  tidier at 11+. This guide loops over a list so going from 1 → 11 is one line.
- **Subnet delegation:** The outbound VNet‑integration subnet for Flex
  Consumption must be delegated to `Microsoft.App/environments` (not
  `Microsoft.Web/serverFarms`, which is the *legacy* App Service delegation).
  This repo's `function_app` module documents exactly this.

### 0.4 You already have most of this in *this* repo

This repository already contains a mature, zone‑redundant Flex Consumption
module at **`modules/function_app`**, consumed by **`vault/function_app_az.tf`**,
with OIDC GitHub Actions in **`.github/workflows/terraform-reusable.yaml`**.
There is **no Logic App module yet** — adding one (Section 8) is the main net‑new
piece for this repo. For your personal subscription, Sections 3–7 give you
self‑contained Terraform you can run alone; Section 9 maps it back to the repo.

---

## 1. The end‑state architecture (Design A)

```
 [ SCHEDULERS ]                 [ COMPUTE ]                    [ PRIVATE BACKEND ]

 Logic App 1  ─┐
 Logic App 2  ─┤  HTTPS POST    ┌────────────────────┐  VNet      ┌──────────────────┐
 ...          ─┼───────────────►│ Azure Function     │ integration│ CP Backend       │
 Logic App 11 ─┘  (Function key │ (Flex Consumption, ├───────────►│ (private endpoint│
                   or Entra ID) │  HTTP trigger, C#) │  (outbound) │  / private IP)   │
                                └────────────────────┘            └──────────────────┘
                                  │  joined to VNet via a subnet
                                  │  delegated to Microsoft.App/environments
                                  ▼
                          ┌───────────────────────────┐
                          │ Storage (deployment pkg)  │  App Insights + Log Analytics
                          │ User‑assigned identity    │  (observability)
                          └───────────────────────────┘
```

Resources you will create:

1. **Resource group** — container for everything.
2. **Virtual network** + 2 subnets:
   - `snet-func-integration` — delegated to `Microsoft.App/environments` (outbound).
   - `snet-private-endpoints` — holds private endpoint NICs (storage, backend).
3. **Storage account** — required by every function app (holds the deployment package).
4. **Log Analytics workspace** + **Application Insights** — logs/telemetry.
5. **User‑assigned managed identity** — the function's identity (storage auth + future Entra calls).
6. **Function App (Flex Consumption)** — runs your C# code.
7. **Logic App(s)** — the timer schedulers.

---

## 2. Prerequisites + Windows local C# dev environment

### 2.1 Azure side

- An **Azure subscription** (your personal one) — https://portal.azure.com
- You are **Owner** or **Contributor + User Access Administrator** on it (needed
  to create role assignments).

### 2.2 Install the tools (Windows)

Open **PowerShell as Administrator** and use `winget` (built into Windows 11):

```powershell
# Azure CLI — talk to Azure from the terminal
winget install --id Microsoft.AzureCLI -e

# Terraform — infrastructure as code
winget install --id HashiCorp.Terraform -e

# .NET 8 SDK (LTS) — build/run C# functions locally
winget install --id Microsoft.DotNet.SDK.8 -e

# Azure Functions Core Tools v4 — run/debug/deploy functions locally
winget install --id Microsoft.Azure.FunctionsCoreTools -e

# Git
winget install --id Git.Git -e

# GitHub CLI (handy for secrets + auth)
winget install --id GitHub.cli -e

# Visual Studio Code + extensions (or use full Visual Studio 2022)
winget install --id Microsoft.VisualStudioCode -e
```

> Close and reopen PowerShell after installing so `PATH` refreshes.

Install the VS Code extensions (run in PowerShell after VS Code is installed):

```powershell
code --install-extension ms-azuretools.vscode-azurefunctions
code --install-extension ms-dotnettools.csharp
code --install-extension hashicorp.terraform
code --install-extension ms-azuretools.vscode-azureresourcegroups
code --install-extension ms-azuretools.vscode-azurelogicapps
```

### 2.3 Verify everything

```powershell
az version
terraform version
dotnet --version          # expect 8.0.x
func --version            # expect 4.x
git --version
```

### 2.4 Log in to Azure

```powershell
az login                                   # opens a browser
az account show                            # confirm the right subscription
az account set --subscription "<your-sub-id>"   # if you have more than one
```

> **Tip:** in this Claude Code session you can run an interactive login yourself
> by typing `! az login` in the prompt — the `!` prefix runs it in the session.

---

## 3. Project layout

Create a working folder for your personal trial (separate from this repo so you
don't accidentally commit experiments into it):

```
logicapp-func-demo/
├─ infra/                 # Terraform
│  ├─ main.tf
│  ├─ network.tf
│  ├─ function.tf
│  ├─ logicapp.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ terraform.tfvars
├─ src/
│  └─ MaintenanceApp/     # C# Function project
└─ .github/
   └─ workflows/
      ├─ infra.yml        # deploy Terraform
      └─ deploy-func.yml  # build + deploy C#
```

```powershell
mkdir logicapp-func-demo; cd logicapp-func-demo
mkdir infra, src, .github\workflows
```

---

## 4. Terraform — provider + state backend

> For a **personal trial**, the simplest path is **local state** (a
> `terraform.tfstate` file on disk). For CI/CD and teamwork you use a **remote
> backend** in Azure Storage (this repo does — see `vault/backend.tf`).
> Section 7.3 shows how to switch.

`infra/main.tf`:

```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.27"   # matches this repo (agents/ uses 4.27.0)
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"    # needed only if you enable zone redundancy
    }
  }
  # Local state for the personal trial. Switch to azurerm backend later (4.x).
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.product}-${var.environment}-${var.short_region}"
  location = var.location
  tags     = var.tags
}
```

`infra/variables.tf`:

```hcl
variable "subscription_id" { type = string }
variable "product"      { type = string,  default = "demo" }
variable "environment"  { type = string,  default = "dev" }
variable "location"     { type = string,  default = "westeurope" }
variable "short_region" { type = string,  default = "weu" }
variable "tags" {
  type = map(string)
  default = {
    Project   = "logicapp-func-demo"
    ManagedBy = "terraform"
  }
}

# Toggle for the inbound design. false = Design A (public inbound, simplest).
variable "function_public_access" { type = bool, default = true }
```

`infra/terraform.tfvars`:

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"  # your sub id
product         = "demo"
environment     = "dev"
location        = "westeurope"   # West Europe supports zone-redundant Flex
short_region    = "weu"
```

> Get your subscription id with `az account show --query id -o tsv`.

---

## 5. Terraform — network, storage, identity, observability

`infra/network.tf`:

```hcl
# ─── Virtual network + subnets ────────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

# Outbound VNet integration subnet for Flex Consumption.
# MUST be delegated to Microsoft.App/environments and dedicated to the function.
resource "azurerm_subnet" "func_integration" {
  name                 = "snet-func-integration"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "flexconsumption"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Subnet that holds private endpoint NICs (storage, and later the CP backend).
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]
}
```

`infra/function.tf` (part 1 — storage, identity, observability):

```hcl
# ─── User-assigned managed identity ───────────────────────────────────────────
resource "azurerm_user_assigned_identity" "func" {
  name                = "id-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# ─── Deployment / host storage account ────────────────────────────────────────
resource "azurerm_storage_account" "func" {
  name                            = lower("st${var.product}${var.environment}${var.short_region}func")
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "LRS"   # ZRS if you enable zone redundancy
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true    # keep open so CI can push the package
  tags                            = var.tags
}

resource "azurerm_storage_container" "deploy" {
  name                  = "app-package"
  storage_account_id    = azurerm_storage_account.func.id
  container_access_type = "private"
}

# The function's identity needs data-plane access to the deployment container.
resource "azurerm_role_assignment" "func_storage" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.func.principal_id
}

# ─── Observability ────────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}
```

`infra/function.tf` (part 2 — the Flex Consumption function app):

```hcl
# ─── Function App (Flex Consumption, FC1) ─────────────────────────────────────
resource "azurerm_service_plan" "func" {
  name                = "asp-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "FC1"      # Flex Consumption
  tags                = var.tags
}

resource "azurerm_function_app_flex_consumption" "main" {
  name                = "func-${var.product}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.func.id

  # Deployment package storage, authenticated with the user-assigned identity.
  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${azurerm_storage_account.func.primary_blob_endpoint}${azurerm_storage_container.deploy.name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.func.id

  runtime_name    = "dotnet-isolated"
  runtime_version = "8.0"            # .NET 8 LTS (repo defaults to 10.0)

  maximum_instance_count = 100
  instance_memory_in_mb  = 2048

  # Design A: public inbound (secured by function key / Entra). Design B: false.
  public_network_access_enabled = var.function_public_access

  # OUTBOUND VNet integration → reach the private CP backend.
  virtual_network_subnet_id = azurerm_subnet.func_integration.id

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.func.id]
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # Identity-based connection for the host storage (no connection strings).
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.func.name
    "AzureWebJobsStorage__credential"  = "managedidentity"
    "AzureWebJobsStorage__clientId"    = azurerm_user_assigned_identity.func.client_id
    # Your own settings:
    "TargetBackendUrl"                 = "https://your-cp-backend.internal"
  }

  depends_on = [azurerm_role_assignment.func_storage]
}
```

> **Design B (fully private inbound)** would add an
> `azurerm_private_endpoint` (subresource `sites`) on the function in
> `snet-private-endpoints`, set `function_public_access = false`, add a
> `privatelink.azurewebsites.net` private DNS zone, and switch the Logic App to
> **Standard** with VNet integration. This repo's `modules/function_app`
> already implements the private‑endpoint side.

---

## 6. The C# Function code

### 6.1 Scaffold the project

```powershell
cd src
func init MaintenanceApp --worker-runtime dotnet-isolated --target-framework net8.0
cd MaintenanceApp
func new --name CentralMaintenanceApi --template "HTTP trigger" --authlevel function
```

### 6.2 Add the ASP.NET Core integration package (needed for `IActionResult`)

```powershell
dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore
dotnet add package Microsoft.Azure.Functions.Worker.ApplicationInsights
```

### 6.3 `Program.cs` — register DI + ASP.NET Core pipeline

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Company.MaintenanceApp;

var host = new HostBuilder()
    // ConfigureFunctionsWebApplication enables the ASP.NET Core HTTP pipeline
    // so handlers can return IActionResult.
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // Your backend communication service (talks to the CP backend over the VNet).
        services.AddScoped<IMaintenanceService, MaintenanceService>();
    })
    .Build();

host.Run();
```

### 6.4 The function (cleaned‑up version of your snippet)

`CentralMaintenanceApi.cs`:

```csharp
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Company.MaintenanceApp;

public class CentralMaintenanceApi
{
    private readonly IMaintenanceService _maintenanceService;
    private readonly ILogger<CentralMaintenanceApi> _logger;

    public CentralMaintenanceApi(IMaintenanceService maintenanceService,
                                 ILogger<CentralMaintenanceApi> logger)
    {
        _maintenanceService = maintenanceService;
        _logger = logger;
    }

    [Function("ExecuteMaintenancePipeline")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "jobs/execute")] HttpRequest req)
    {
        _logger.LogInformation("Scheduled maintenance signal received.");

        var payload = await JsonSerializer.DeserializeAsync<SchedulerPayload>(
            req.Body,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (payload is null || string.IsNullOrWhiteSpace(payload.JobName))
            return new BadRequestObjectResult(new { error = "JobName is required." });

        _logger.LogInformation("Job {Job} targeting {Target}", payload.JobName, payload.TargetEnv);

        try
        {
            await _maintenanceService.RunCoreTasksAsync(payload);
            return new OkObjectResult(new { status = "Success", executedJob = payload.JobName });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Maintenance routine failed for {Job}.", payload.JobName);
            // 500 lets the Logic App retry policy kick in.
            return new StatusCodeResult(StatusCodes.Status500InternalServerError);
        }
    }
}

public record SchedulerPayload
{
    public string JobName { get; init; } = "";
    public string TargetEnv { get; init; } = "";
    public bool ForceRun { get; init; }
}

public interface IMaintenanceService
{
    Task RunCoreTasksAsync(SchedulerPayload payload);
}

// Stub — replace the body with your real CP backend call (HttpClient to the
// private endpoint). VNet integration makes the private host resolvable.
public class MaintenanceService : IMaintenanceService
{
    private readonly ILogger<MaintenanceService> _logger;
    public MaintenanceService(ILogger<MaintenanceService> logger) => _logger = logger;

    public Task RunCoreTasksAsync(SchedulerPayload payload)
    {
        _logger.LogInformation("Running core tasks for {Job} (force={Force}).",
            payload.JobName, payload.ForceRun);
        return Task.CompletedTask;
    }
}
```

### 6.5 Run it locally

```powershell
func start
```

In a second terminal, call it:

```powershell
$body = '{"JobName":"UpcomingExpiredPrograms","TargetEnv":"CP-Dev","ForceRun":false}'
Invoke-RestMethod -Uri http://localhost:7071/api/jobs/execute -Method Post -Body $body -ContentType application/json
```

You should get `{ "status": "Success", "executedJob": "UpcomingExpiredPrograms" }`.

> **Local debugging in VS Code:** press **F5**. The Azure Functions extension
> wires up the debugger automatically (set breakpoints in `Run`). `local.settings.json`
> holds your local-only settings and is git‑ignored — never commit secrets.

### 6.6 Deploy manually once (to confirm it works before CI/CD)

```powershell
func azure functionapp publish func-demo-dev-weu --dotnet-isolated
```

Get the function URL + key from the portal (Function App → Functions →
`ExecuteMaintenancePipeline` → Get Function Url), or:

```powershell
az functionapp function keys list -g rg-demo-dev-weu -n func-demo-dev-weu `
  --function-name ExecuteMaintenancePipeline
```

---

## 7. Logic App schedulers (Terraform)

`infra/logicapp.tf` — a **Consumption** Logic App per schedule, looping over a
list so 1 → 11 schedules is just more list entries:

```hcl
variable "schedules" {
  description = "One Logic App per entry. Adjust frequency/interval per schedule."
  type = list(object({
    name      = string
    job_name  = string
    frequency = string   # Second/Minute/Hour/Day/Week/Month
    interval  = number
  }))
  default = [
    { name = "expired-programs", job_name = "UpcomingExpiredPrograms", frequency = "Day",  interval = 1 },
    { name = "weekly-cleanup",   job_name = "WeeklyExpiredCleanup",    frequency = "Week", interval = 1 },
    # ... add up to 11 ...
  ]
}

# Read the function's default host key so the Logic App can authenticate.
data "azurerm_function_app_host_keys" "main" {
  name                = azurerm_function_app_flex_consumption.main.name
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_logic_app_workflow" "schedule" {
  for_each            = { for s in var.schedules : s.name => s }
  name                = "logic-${var.product}-${each.value.name}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# Recurrence trigger.
resource "azurerm_logic_app_trigger_recurrence" "schedule" {
  for_each     = azurerm_logic_app_workflow.schedule
  name         = "Recurrence"
  logic_app_id = each.value.id
  frequency    = var.schedules[index(var.schedules[*].name, each.key)].frequency
  interval     = var.schedules[index(var.schedules[*].name, each.key)].interval
}

# HTTP POST action → the function.
resource "azurerm_logic_app_action_http" "call_function" {
  for_each     = azurerm_logic_app_workflow.schedule
  name         = "CallFunction"
  logic_app_id = each.value.id
  method       = "POST"
  uri          = "https://${azurerm_function_app_flex_consumption.main.default_hostname}/api/jobs/execute?code=${data.azurerm_function_app_host_keys.main.default_function_key}"

  headers = { "Content-Type" = "application/json" }

  body = jsonencode({
    JobName   = [for s in var.schedules : s.job_name if s.name == each.key][0]
    TargetEnv = "CP-${var.environment}"
    ForceRun  = false
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.schedule]
}
```

> **Portal alternative (no Terraform for the workflow):** Create a Logic App
> (Consumption) → **Recurrence** trigger → **HTTP** action → POST to the
> function URL with the `x-functions-key` header and the JSON body. This is what
> your original write‑up described, and it's perfect for clicking around while
> learning. Terraform is better once you have 11 of them.

### 7.1 Upgrade: managed identity instead of function keys (recommended)

Putting `?code=<key>` in the URL works but leaks a secret into the workflow
definition. The better pattern:

1. Enable a **system‑assigned identity** on the Logic App (`identity { type = "SystemAssigned" }`).
2. In the function, set auth level to **anonymous** but turn on **App
   Service Authentication (Easy Auth)** requiring a token, OR validate the
   Entra token in code.
3. In the Logic App HTTP action, set **Authentication = Managed identity** with
   the function app's Application ID URI as the audience.

For a personal trial, keys are acceptable. Switch to MI before anything real.

### 7.2 `terraform apply`

```powershell
cd infra
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

`infra/outputs.tf`:

```hcl
output "function_app_name"     { value = azurerm_function_app_flex_consumption.main.name }
output "function_app_hostname" { value = azurerm_function_app_flex_consumption.main.default_hostname }
output "resource_group"        { value = azurerm_resource_group.main.name }
```

### 7.3 Switch to remote state (when moving toward CI/CD)

Create a state storage account once, then replace the `terraform {}` block's
local state with:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "sttfstateyourname"
  container_name       = "tfstate"
  key                  = "logicapp-func-demo.tfstate"
}
```

```powershell
# one-time bootstrap
az group create -n rg-tfstate -l westeurope
az storage account create -n sttfstateyourname -g rg-tfstate -l westeurope --sku Standard_LRS
az storage container create -n tfstate --account-name sttfstateyourname
terraform init -migrate-state
```

This repo uses exactly this pattern — see `vault/backend.tf` (`backend "azurerm" {}`,
config passed at `init` time via `-backend-config`).

---

## 8. CI/CD with GitHub Actions (OIDC — no stored passwords)

This repo authenticates to Azure with **OIDC federated credentials** (no client
secrets), via `azure/login@v2` + `ARM_USE_OIDC=true`. Mirror that.

### 8.1 One‑time Azure setup: app registration + federated credential

```powershell
# Create an app registration + service principal
$appId = az ad app create --display-name "gh-logicapp-func-demo" --query appId -o tsv
az ad sp create --id $appId

# Give it rights on your subscription (Contributor + access to assign roles)
$subId = az account show --query id -o tsv
az role assignment create --assignee $appId --role "Contributor" --scope "/subscriptions/$subId"
az role assignment create --assignee $appId --role "User Access Administrator" --scope "/subscriptions/$subId"

# Federate it to your GitHub repo's `dev` environment (replace OWNER/REPO)
az ad app federated-credential create --id $appId --parameters '{
  "name": "gh-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:OWNER/REPO:environment:dev",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

Add three GitHub repo secrets (Settings → Secrets and variables → Actions):

```powershell
gh secret set AZURE_CLIENT_ID       --body $appId
gh secret set AZURE_TENANT_ID       --body (az account show --query tenantId -o tsv)
gh secret set AZURE_SUBSCRIPTION_ID --body $subId
```

Create a GitHub **Environment** named `dev` (Settings → Environments) — the repo
workflows key off environments for approvals.

### 8.2 Infra workflow — `.github/workflows/infra.yml`

```yaml
name: Infra (Terraform)

on:
  push:
    branches: [main]
    paths: ['infra/**']
  workflow_dispatch:

permissions:
  contents: read
  id-token: write        # required for OIDC

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: dev
    defaults:
      run:
        working-directory: infra
    env:
      ARM_USE_OIDC: "true"
      ARM_USE_AZUREAD: "true"
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.15.6   # matches this repo's pinned version

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - run: terraform init
      - run: terraform validate
      - run: terraform plan -out tf.plan -var "subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"
      - run: terraform apply -auto-approve tf.plan
```

> This repo splits plan and apply into separate jobs with a plan artifact and a
> rich job summary — see `.github/workflows/terraform-reusable.yaml`. For a
> personal trial the single job above is fine; graduate to the reusable workflow
> when you bring this into the repo.

### 8.3 Function deploy workflow — `.github/workflows/deploy-func.yml`

```yaml
name: Deploy Function

on:
  push:
    branches: [main]
    paths: ['src/**']
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

env:
  FUNCTION_APP_NAME: func-demo-dev-weu
  DOTNET_VERSION: '8.0.x'
  PROJECT_PATH: src/MaintenanceApp

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Build & publish
        run: |
          dotnet publish ${{ env.PROJECT_PATH }} -c Release -o ./output

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Azure Functions
        uses: Azure/functions-action@v1
        with:
          app-name: ${{ env.FUNCTION_APP_NAME }}
          package: ./output
```

> **Order matters:** run **Infra** first (creates the function app), then
> **Deploy Function** (pushes code). On every later code change, only
> `deploy-func.yml` runs (it's path‑filtered to `src/**`).

---

## 9. Bringing it into THIS repo (when ready)

Your personal trial maps cleanly onto this repo's existing building blocks:

| Personal trial (Section) | This repo's equivalent |
|--------------------------|------------------------|
| `infra/function.tf` (Flex function) | `modules/function_app` (already built, zone‑redundant, private‑endpoint capable) consumed by `vault/function_app_az.tf` |
| `infra/network.tf` subnets | `modules/vnet` — add a `function-integration` subnet delegated to `Microsoft.App/environments` (the module already supports delegations) |
| `infra/logicapp.tf` | **Net‑new**: create a `modules/logic_app` module (none exists yet) following the same naming/tagging/`lifecycle { ignore_changes = [tags] }` conventions |
| Storage / App Insights / Log Analytics | `modules/storage_account`, `modules/app_insight`, `modules/log_workspace` |
| `infra.yml` | `.github/workflows/terraform-reusable.yaml` (+ a caller like `vault-infra.yaml`) |
| OIDC login | Already standard across the repo's workflows |

Concretely, the repo already exposes these knobs in tfvars (see
`vault/dev/*.tfvars`):

```hcl
enable_function_app                        = true
function_app_name                          = "maintenance-svc"
function_app_runtime_name                  = "dotnet-isolated"
function_app_runtime_version               = "10.0"
function_app_private_endpoint_enabled      = true
function_app_public_network_access_enabled = false   # Design B in the repo
```

> Note the repo runs **Design B** (`public_network_access_enabled = false` +
> private endpoint). If your Logic App must call that function, it has to be
> **Logic Apps Standard** inside the VNet, or you call the function from
> something already on the network. Decide this before adding the Logic App
> module.

---

## 10. Testing & troubleshooting

- **Watch live logs:** Portal → Function App → **Log stream**, or
  `func azure functionapp logstream func-demo-dev-weu`.
- **Trigger a Logic App now:** Portal → Logic App → **Run Trigger** → Recurrence.
  Then **Runs history** shows each run, the request/response, and a **Resubmit**
  button — this is the "out‑of‑the‑box retries / resubmit" benefit you cited.
- **App Insights:** Portal → Application Insights → **Transaction search** /
  **Live metrics** to trace each invocation end to end.

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `401`/`403` from function | Wrong/missing function key | Re‑read the key; check the `?code=` / `x-functions-key` value |
| Logic App can't reach function | You disabled public access (Design B) on a Consumption Logic App | Re‑enable public access, or move to Logic Apps Standard + VNet |
| Function can't reach CP backend | VNet integration / DNS not set up | Confirm `virtual_network_subnet_id` is set and the backend's private DNS resolves from the integration subnet |
| Deploy fails: storage auth | Identity lacks `Storage Blob Data Owner` | Confirm the role assignment applied; it can take a minute to propagate |
| `subnet must be delegated` error | Wrong delegation | Must be `Microsoft.App/environments` for Flex Consumption |
| Terraform: unknown resource `azurerm_function_app_flex_consumption` | Old provider | Use azurerm `>= 4.x` |

---

## 11. Cost & cleanup (personal subscription)

- **Flex Consumption** scales to zero — you pay per execution + a little for the
  always‑allocated memory baseline. Cheap for 11 light schedules.
- **Consumption Logic Apps** bill per action executed — also cheap at this volume.
- **Storage / App Insights / Log Analytics** are the small fixed costs. Cap Log
  Analytics retention at 30 days and set a daily ingestion cap if worried.

**Tear everything down when done experimenting:**

```powershell
cd infra
terraform destroy   # removes everything Terraform created
```

> `terraform destroy` only removes what's in *this* state. The `rg-tfstate`
> bootstrap storage (Section 7.3) and the GitHub app registration are separate —
> delete those manually if you no longer need them.

---

## 12. Quick reference — the whole flow

1. Install tools (Section 2) → `az login`.
2. `terraform apply` in `infra/` → infra exists (Sections 4–7).
3. `func azure functionapp publish` → code is live (Section 6.6).
4. Logic Apps fire on schedule → POST to the function → function runs core
   logic over the VNet to the CP backend.
5. Commit to GitHub → Actions redeploy infra and code automatically (Section 8).
6. `terraform destroy` to clean up (Section 11).

---

### Authoritative references (look these up to go deeper)

- Microsoft Learn: **"Azure Functions Flex Consumption networking options"** — subnet delegation + VNet integration.
- Microsoft Learn: **"Call Azure Functions from Azure Logic Apps"** — the HTTP handshake, keys, and the managed‑identity upgrade.
- Microsoft Learn: **"Connect to virtual networks from Azure Logic Apps (Standard)"** — required for Design B (private inbound).
- Terraform Registry: `azurerm_function_app_flex_consumption`, `azurerm_logic_app_workflow`, `azurerm_logic_app_trigger_recurrence`, `azurerm_logic_app_action_http`.
- This repo: `modules/function_app/`, `vault/function_app_az.tf`, `.github/workflows/terraform-reusable.yaml`.
```
