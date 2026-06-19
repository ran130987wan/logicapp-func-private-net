# Implementation Instructions (Scaffold)

## 1. Prepare repository

1. Copy template folders into your new repository.
2. Add or update .gitignore for terraform state, plans, and build outputs.
3. Add AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID as repository secrets.

## 2. Configure infrastructure

1. Set environment values in infra/environments/dev/terraform.private.tfvars.
2. Define schedules with one workflow per entry.
3. Use Design A by default for a runnable POC:
   - Public Function hostname
   - Function key auth on inbound
   - Private outbound via VNet integration where needed

## 3. Validate locally

1. terraform -chdir=infra fmt -recursive
2. terraform -chdir=infra init -backend=false
3. terraform -chdir=infra validate
4. dotnet build src/MaintenanceApp/MaintenanceApp.csproj -c Release

## 4. Deploy via workflow

1. Trigger Infra workflow with apply=true only when approved.
2. Deploy function app code.
3. Read the function host key.
4. Re-apply Terraform with function_host_key to add Logic App CallFunction actions.
5. Run trigger/log validation and capture evidence.

## 5. Operate safely

1. Never auto-run destroy.
2. Keep teardown steps documented and reversible.
3. Record known issues and fixes in repository memory notes.
