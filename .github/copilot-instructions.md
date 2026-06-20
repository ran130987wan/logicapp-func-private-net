# Copilot Repository Instructions

This repository deploys a Logic Apps + Azure Function pattern with private outbound networking.

## Architecture assumptions

- POC target is private infrastructure first: private inbound for the Function app and private networking requirements for Logic Apps.
- Keep Function outbound traffic on delegated subnet integration (Microsoft.App/environments).
- Use the private tfvars profile (`infra/environments/dev/terraform.private.tfvars`) for infra workflows.
- Keep Terraform modules simple and composable.

## Coding conventions

- Prefer incremental Terraform changes over broad rewrites.
- Keep variable names explicit and environment-aware.
- Add outputs for key resource names and hostnames.
- Keep scripts portable for Linux dev containers.

## Safety guardrails

- Do not add secrets to source control.
- Use OIDC in workflows instead of client secrets.
- Do not disable TLS or reduce secure defaults.

## Useful commands

- terraform -chdir=infra init
- terraform -chdir=infra plan -var-file=terraform.tfvars
- dotnet build src/MaintenanceApp/MaintenanceApp.csproj
