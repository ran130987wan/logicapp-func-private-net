# 🎯 Execution Guide: Running the POC End-to-End

This guide walks you through **actually running** this Logic Apps + Function POC from start to finish.

---

## Table of Contents

1. [Prerequisites Checklist](#prerequisites-checklist)
2. [Phase 1: Environment Setup](#phase-1-environment-setup)
3. [Phase 2: Local Validation](#phase-2-local-validation)
4. [Phase 3: Infrastructure Deployment](#phase-3-infrastructure-deployment)
5. [Phase 4: Function Deployment](#phase-4-function-deployment)
6. [Phase 5: Logic App Verification](#phase-5-logic-app-verification)
7. [Phase 6: E2E Testing](#phase-6-e2e-testing)
8. [Troubleshooting & Debugging](#troubleshooting--debugging)
9. [Cleanup](#cleanup)

---

## Prerequisites Checklist

### Azure Subscription

- [ ] Active Azure subscription
- [ ] Sufficient quota for:
  - Consumption Logic Apps
  - Flex Consumption Function App
  - Storage account
  - Virtual Network
  - Log Analytics workspace
- [ ] Permission to create resources in target resource group
- [ ] **Recommended:** Use dev/test subscription first (not production)

### Local Machine / Codespace

- [ ] Git installed (`git --version` should show v2.x+)
- [ ] Azure CLI installed (`az --version` should show 2.87.0+)
- [ ] Terraform installed (`terraform version` should show 1.15.6+)
- [ ] .NET SDK installed (`dotnet --version` should show 8.0+)
- [ ] Azure Functions Core Tools (`func --version` should show 4.12+)
- [ ] Bash shell (Linux/macOS/Codespaces; Windows users: WSL2 recommended)

### GitHub Repository

- [ ] Forked or cloned this repository
- [ ] Branch: `main` or `feat/poc-governance-memory-tuning`
- [ ] Able to push commits (for storing Terraform state remotely, optional)

### Azure CLI Configuration

- [ ] Logged into Azure: `az login`
- [ ] Target subscription set: `az account set --subscription <sub-id>`
- [ ] Can list resource groups: `az group list --output table`

---

## Phase 1: Environment Setup

### 1.1 Clone Repository

```bash
# Clone the repository
git clone https://github.com/ran130987wan/logicapp-func-private-net.git
cd logicapp-func-private-net

# Verify structure
ls -la
# Expected: README.md, infra/, src/, development/, docs/, scaffold/, .github/
```

### 1.2 Run Bootstrap Script

```bash
# Make bootstrap script executable
chmod +x development/scripts/bootstrap.sh

# Run bootstrap (installs missing tools, validates prerequisites)
./development/scripts/bootstrap.sh

# Expected output:
# ✓ Git installed
# ✓ Azure CLI installed
# ✓ Terraform installed
# ✓ .NET SDK installed
# ✓ Azure Functions Core Tools installed
# ✓ All prerequisites met
```

**If bootstrap fails:**
- Check [Troubleshooting](#troubleshooting--debugging) section
- Manually install missing tools from [Prerequisites Checklist](#prerequisites-checklist)

### 1.3 Login to Azure

```bash
# Interactive login (opens browser)
az login --tenant b52aa991-8ac7-4b6c-8bc9-03fb21d0d4ac

# Set target subscription
az account set --subscription cf83455a-73e2-41b7-b28b-fbbf1467713d

# Verify login
az account show --output table
# Expected: Shows your subscription ID and account info
```

### 1.4 Prepare Terraform Configuration

```bash
# Navigate to infra directory
cd infra

# Initialize Terraform (downloads Azure provider)
terraform init

# Verify structure
ls -la
# Expected: main.tf, network.tf, function.tf, logicapp.tf, variables.tf, outputs.tf, environments/

# Check environments
ls -la environments/
# Expected: dev/ folder with terraform.private.tfvars
```

---

## Phase 2: Local Validation

### 2.1 Terraform Format & Validation

```bash
# Check Terraform formatting
terraform fmt -recursive

# Validate configuration (checks syntax)
terraform validate
# Expected: Success! The configuration is valid.
```

### 2.2 Plan Infrastructure (Dry Run)

```bash
# Plan deployment without applying
terraform plan -var-file=environments/dev/terraform.private.tfvars -out=tfplan.bin

# Review output:
# - Should show ~15-20 resources to create
# - Check for any errors before proceeding
# - Note resource names (e.g., demo-dev-weu-rg)
```

### 2.3 Build Function Locally

```bash
# Navigate to function source
cd ../src/MaintenanceApp

# Restore dependencies
dotnet restore

# Build in Release mode
dotnet build -c Release

# Expected output:
# Build succeeded.
# 0 Warning(s), 0 Error(s)

# Verify build output
ls -la bin/Release/net8.0/
# Expected: MaintenanceApp.dll, function.json, etc.
```

### 2.4 Run Function Locally

```bash
# Start local Function runtime
func start

# Expected output:
# Azure Functions Core Tools (4.12.0 or later)
# ...
# Now listening on: http://localhost:7071
# ...
# Functions in this function app:
# ExecuteMaintenancePipeline: [POST] http://localhost:7071/api/jobs/execute

# Keep this terminal open (server running)
```

### 2.5 Test Local Endpoint

**In a new terminal:**

```bash
# Test function endpoint
curl -X POST http://localhost:7071/api/jobs/execute \
  -H "Content-Type: application/json" \
  -d '{"JobName":"test-daily","TargetEnv":"dev","ForceRun":false}'

# Expected response (HTTP 200):
# {
#   "status": "success",
#   "jobName": "test-daily",
#   "executedAt": "2026-06-19T10:30:00Z",
#   "taskCount": 3
# }

# Try with invalid payload
curl -X POST http://localhost:7071/api/jobs/execute \
  -H "Content-Type: application/json" \
  -d '{"invalid":"payload"}'

# Expected: HTTP 400 Bad Request (validation error)
```

**Go back to first terminal and stop the function:**
```bash
# Press Ctrl+C to stop local runtime
# (or send SIGTERM signal)
```

✅ **Local validation complete.** Function works and validates payloads correctly.

---

## Phase 3: Infrastructure Deployment

### 3.1 Apply Terraform

```bash
# Navigate back to infra directory
cd /workspaces/logicapp-func-private-net/infra

# Apply infrastructure (this actually creates resources)
terraform apply -var-file=environments/dev/terraform.private.tfvars -auto-approve

# Expected output:
# ...
# Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
#
# Outputs:
# function_app_name = "demo-dev-weu-func"
# resource_group_name = "demo-dev-weu-rg"
# ...

# Save outputs for next phase
terraform output -json > outputs.json
cat outputs.json
```

### 3.2 Verify Resources in Azure

```bash
# List created resources
az resource list --resource-group demo-dev-weu-rg --output table

# Expected: Function App, Storage, VNet, Logic Apps, Log Analytics, etc.

# Get Function App details
az functionapp show --name demo-dev-weu-func --resource-group demo-dev-weu-rg

# Get VNet details
az network vnet show --name demo-dev-weu-vnet --resource-group demo-dev-weu-rg --output table
```

### 3.3 Retrieve Function Key

```bash
# Get function keys
az rest --method POST \
  --url "https://management.azure.com/subscriptions/cf83455a-73e2-41b7-b28b-fbbf1467713d/resourceGroups/demo-dev-weu-rg/providers/Microsoft.Web/sites/demo-dev-weu-func/host/default/listkeys?api-version=2022-03-01" \
  --query "functionKeys.default" -o tsv

# Expected: Base64-encoded key (e.g., a1b2c3d4e5f6g7h8...)
# Save this key — you'll need it for Logic App configuration
```

### 3.4 Verify Network Configuration

```bash
# Check VNet
az network vnet show --name demo-dev-weu-vnet --resource-group demo-dev-weu-rg

# Check NSG rules
az network nsg rule list --resource-group demo-dev-weu-rg --nsg-name demo-dev-weu-nsg

# Verify Function App VNet integration
az functionapp vnet-integration list --name demo-dev-weu-func --resource-group demo-dev-weu-rg
```

✅ **Infrastructure deployed.** All resources created and configured.

---

## Phase 4: Function Deployment

### 4.1 Publish Function to Azure

```bash
# Navigate to function source
cd src/MaintenanceApp

# Publish function app
func azure functionapp publish demo-dev-weu-func

# Expected output:
# Getting site publishing credentials for function app
# ...
# Deployment successful. Remote build succeeded!
```

### 4.2 Verify Function is Running

```bash
# Check function status
az functionapp show --name demo-dev-weu-func --resource-group demo-dev-weu-rg \
  --query "state" --output tsv
# Expected: Running

# Get function app URL
FUNC_URL=$(az functionapp show --name demo-dev-weu-func --resource-group demo-dev-weu-rg \
  --query "defaultHostName" --output tsv)
echo "Function URL: $FUNC_URL"
# Expected: demo-dev-weu-func.azurewebsites.net
```

### 4.3 Test Function Endpoint via Azure

```bash
# Get function key
FUNC_KEY=$(az rest --method POST \
  --url "https://management.azure.com/subscriptions/cf83455a-73e2-41b7-b28b-fbbf1467713d/resourceGroups/demo-dev-weu-rg/providers/Microsoft.Web/sites/demo-dev-weu-func/host/default/listkeys?api-version=2022-03-01" \
  --query "functionKeys.default" -o tsv)

# Test function endpoint
curl -X POST "https://${FUNC_URL}/api/jobs/execute?code=${FUNC_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"JobName":"test-azure","TargetEnv":"dev","ForceRun":false}'

# Expected: HTTP 200 + response body with execution details
```

### 4.4 Check Application Insights

```bash
# Get Application Insights resource
az monitor app-insights component show \
  --app demo-dev-weu-ai \
  --resource-group demo-dev-weu-rg

# Check recent telemetry (may take 1-2 minutes)
az monitor metrics list \
  --resource /subscriptions/cf83455a-73e2-41b7-b28b-fbbf1467713d/resourceGroups/demo-dev-weu-rg/providers/Microsoft.Insights/components/demo-dev-weu-ai \
  --metric "Requests/Count" \
  --aggregation Total
```

✅ **Function deployed and responding.** Ready for Logic App wiring.

---

## Phase 5: Logic App Verification

### 5.1 Check Logic Apps in Portal

```bash
# List deployed Logic Apps
az logic workflow list --resource-group demo-dev-weu-rg --output table

# Expected: 3 workflows
# - demo-dev-daily-expired-programs
# - demo-dev-12h-hourly-reconcile
# - demo-dev-weekly-weekly-cleanup
```

### 5.2 Verify Logic App HTTP Action Configuration

```bash
# Get Logic App definition (first one)
az logic workflow definition show \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg \
  | jq '.actions.HTTP_Invoke.inputs.uri' # Check if function URL is set with key

# Expected output shows URI with function key appended:
# "https://demo-dev-weu-func.azurewebsites.net/api/jobs/execute?code=<FUNC_KEY>"
```

### 5.3 Manual Logic App Test

```bash
# Trigger a workflow manually
az logic workflow run create \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg

# Expected: Returns run ID (e.g., 08587363633...)

# Monitor the run
RUN_ID="08587363633..." # from previous command
az logic workflow run show \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg \
  --run-id ${RUN_ID} \
  --query "{status: status, startTime: startTime, endTime: endTime}"

# Expected: status = "Succeeded"
```

### 5.4 Check Log Analytics Logs

```bash
# Query logs for workflow executions
az monitor log-analytics query \
  --workspace demo-dev-weu-la \
  --resource-group demo-dev-weu-rg \
  --analytics-query 'AzureDiagnostics 
    | where Category == "WorkflowRuntime" 
    | where ResourceProvider == "Microsoft.Logic"
    | top 10 by TimeGenerated desc'

# Expected: Shows recent workflow executions
```

✅ **Logic Apps configured and working.** Ready for e2e testing.

---

## Phase 6: E2E Testing

### 6.1 Trigger All Three Schedules Manually

```bash
# Trigger Daily workflow
echo "Triggering Daily (expired-programs)..."
az logic workflow run create \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg \
  --query "name" --output tsv

# Trigger 12h workflow
echo "Triggering 12h (hourly-reconcile)..."
az logic workflow run create \
  --name demo-dev-12h-hourly-reconcile \
  --resource-group demo-dev-weu-rg \
  --query "name" --output tsv

# Trigger Weekly workflow
echo "Triggering Weekly (weekly-cleanup)..."
az logic workflow run create \
  --name demo-dev-weekly-weekly-cleanup \
  --resource-group demo-dev-weu-rg \
  --query "name" --output tsv

# Wait 30 seconds for executions to complete
sleep 30

echo "✓ All three workflows triggered"
```

### 6.2 Verify All Executions Succeeded

```bash
# Check Daily execution
az logic workflow run list \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg \
  --query "[0].{status: status, endTime: endTime, properties: properties}" \
  --output json | jq '.status'

# Check 12h execution
az logic workflow run list \
  --name demo-dev-12h-hourly-reconcile \
  --resource-group demo-dev-weu-rg \
  --query "[0].{status: status}" --output json | jq '.status'

# Check Weekly execution
az logic workflow run list \
  --name demo-dev-weekly-weekly-cleanup \
  --resource-group demo-dev-weu-rg \
  --query "[0].{status: status}" --output json | jq '.status'

# Expected: All show "Succeeded"
```

### 6.3 Inspect Log Analytics for Full Traces

```bash
# Query all traces from this execution
az monitor log-analytics query \
  --workspace demo-dev-weu-la \
  --resource-group demo-dev-weu-rg \
  --analytics-query 'traces 
    | where timestamp > ago(5m)
    | where tostring(customDimensions.Category) == "JobExecution"
    | project timestamp, message, customDimensions.JobName, customDimensions.Status'

# Expected: Shows 3 job executions (Daily, 12h, Weekly)
```

### 6.4 Check Application Insights Metrics

```bash
# Get function execution statistics
az monitor app-insights metrics show \
  --app demo-dev-weu-ai \
  --resource-group demo-dev-weu-rg \
  --metric "server_requests_count" \
  --aggregation Count

# Expected: Should show at least 3 requests (1 per workflow)
```

### 6.5 Run Automated Trigger Validation Script

```bash
# If available, run the validation script
cd /workspaces/logicapp-func-private-net
chmod +x development/scripts/validate-trigger-logs.sh

./development/scripts/validate-trigger-logs.sh

# Expected output:
# ✓ Daily workflow executed successfully
# ✓ 12h workflow executed successfully
# ✓ Weekly workflow executed successfully
# ✓ All three triggers validated
```

✅ **E2E testing complete.** All three schedules triggered, executed, and logged.

---

## Troubleshooting & Debugging

### Issue: Terraform Init Fails

```bash
# Problem: "Failed to configure backend"
# Solution:
terraform init -reconfigure
# Then follow prompts

# Problem: "Provider version not available"
# Solution:
rm -rf .terraform
terraform init
```

### Issue: Function Won't Deploy

```bash
# Problem: "Authentication error"
# Solution:
az logout
az login --tenant b52aa991-8ac7-4b6c-8bc9-03fb21d0d4ac

# Problem: "Deployment slot not available"
# Solution: Check if function app exists first
az functionapp show --name demo-dev-weu-func --resource-group demo-dev-weu-rg
```

### Issue: Logic App Returns 401 Unauthorized

```bash
# Problem: Function key not correct
# Solution: Regenerate key
az rest --method POST \
  --url "https://management.azure.com/subscriptions/.../regenerateKey?keyType=default&api-version=2022-03-01" \
  | jq '.defaultKey'

# Update Terraform variable and reapply
terraform apply -var-file=environments/dev/terraform.private.tfvars
```

### Issue: VNet Integration Not Working

```bash
# Problem: Function can't reach backend
# Solution: Check NSG rules
az network nsg rule list --nsg-name demo-dev-weu-nsg --resource-group demo-dev-weu-rg

# Check delegated subnet
az network vnet subnet show --name demo-dev-weu-delegated-subnet \
  --vnet-name demo-dev-weu-vnet \
  --resource-group demo-dev-weu-rg
```

### Issue: Cold Start Latency High

```bash
# Problem: First request takes 5+ seconds
# Expected: This is normal for Flex Consumption (cold start)
# Solution: Depends on use case
# - If unacceptable, consider Premium plan
# - If acceptable, keep Flex Consumption (cheaper)

# Monitor: Check Application Insights "server_response_time"
az monitor app-insights metrics show \
  --app demo-dev-weu-ai \
  --resource-group demo-dev-weu-rg \
  --metric "server_response_time"
```

### Debug: View Detailed Logs

```bash
# Stream logs from function app
az functionapp log tail --name demo-dev-weu-func --resource-group demo-dev-weu-rg

# View Log Analytics data
az monitor log-analytics query \
  --workspace demo-dev-weu-la \
  --resource-group demo-dev-weu-rg \
  --analytics-query 'AppTraces 
    | top 50 by TimeGenerated desc'
```

---

## Cleanup

### Option 1: Delete Individual Resources (Keep Learning)

```bash
# Stop Logic App schedules (so they don't keep running)
az logic workflow update \
  --name demo-dev-daily-expired-programs \
  --resource-group demo-dev-weu-rg \
  --set properties.state=Disabled

az logic workflow update \
  --name demo-dev-12h-hourly-reconcile \
  --resource-group demo-dev-weu-rg \
  --set properties.state=Disabled

az logic workflow update \
  --name demo-dev-weekly-weekly-cleanup \
  --resource-group demo-dev-weu-rg \
  --set properties.state=Disabled
```

### Option 2: Delete Entire Resource Group (Complete Cleanup)

```bash
# WARNING: This deletes everything (all resources in the group)
az group delete --name demo-dev-weu-rg --yes --no-wait

# Or use Terraform:
cd infra
terraform destroy -var-file=environments/dev/terraform.private.tfvars -auto-approve

# Clean up local state
rm -rf .terraform terraform.tfstate* tfplan.bin
```

### Option 3: Keep Infrastructure Running (For Repeated Testing)

```bash
# Just disable Logic App schedules to save cost
az logic workflow update --name demo-dev-daily-expired-programs --resource-group demo-dev-weu-rg --set properties.state=Disabled
az logic workflow update --name demo-dev-12h-hourly-reconcile --resource-group demo-dev-weu-rg --set properties.state=Disabled
az logic workflow update --name demo-dev-weekly-weekly-cleanup --resource-group demo-dev-weu-rg --set properties.state=Disabled

# Infrastructure remains; cost drops to ~$0.15/month (only Function + Storage + Logging)
```

---

## Validation Checklist

Use this checklist to verify each phase is complete:

- [ ] **Phase 1:** Azure CLI logged in; Terraform initialized; prerequisites installed
- [ ] **Phase 2:** Function builds locally; local endpoint responds with HTTP 200
- [ ] **Phase 3:** Terraform apply succeeds; resources visible in Azure Portal
- [ ] **Phase 4:** Function deployed to Azure; endpoint returns 200 with function key
- [ ] **Phase 5:** Logic Apps visible; HTTP actions reference function URL with key
- [ ] **Phase 6:** All three schedules triggered manually; all executions succeeded
- [ ] **Logs:** Application Insights shows 3 function calls; Log Analytics captures traces

**If all checkmarks complete:** ✅ POC successfully executed end-to-end

---

## Next Steps After Successful Execution

### For Learning

1. **Modify the Function:** Add new business logic to `CentralMaintenanceApi.cs`
2. **Add a New Schedule:** Create a 4th schedule in `terraform.private.tfvars`
3. **Extend Logging:** Increase Log Analytics retention to 60 days
4. **Test Failures:** Intentionally break the Function and observe error handling

### For Production

1. **Migrate to Design B:** Read [ARCHITECTURE-DECISIONS.md](ARCHITECTURE-DECISIONS.md#adrsection-adr-002-flex-consumption-function-vs-premium-vs-dedicated)
2. **Setup CI/CD:** Deploy via GitHub Actions workflows
3. **Enable Monitoring Alerts:** Configure Log Analytics alerts for failed executions
4. **Implement Audit Trail:** Store execution history for compliance

### For Scaling

1. **Increase Trigger Frequency:** Reference [Cost Scaling Scenarios](ONBOARDING-NEW-CONTRIBUTOR.md#cost-scaling-scenarios)
2. **Add Multiple Functions:** Deploy separate function per domain
3. **Use Managed Identities:** Upgrade from Function Keys to Azure AD

---

## Support & Documentation

- **Architecture questions?** → [ARCHITECTURE-DECISIONS.md](ARCHITECTURE-DECISIONS.md)
- **Cost analysis?** → [ONBOARDING-NEW-CONTRIBUTOR.md#monthly-costing](ONBOARDING-NEW-CONTRIBUTOR.md)
- **Governance policies?** → [docs/GOVERNANCE.md](GOVERNANCE.md)
- **Repository structure?** → [docs/STRUCTURE.md](STRUCTURE.md)

---

**Last updated:** June 2026  
**Estimated execution time:** 30–45 minutes (first run)  
**Prerequisites:** Azure subscription, local dev environment, Git
