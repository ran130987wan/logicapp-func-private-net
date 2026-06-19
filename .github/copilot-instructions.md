# Copilot Repository Instructions

This repository deploys a Logic Apps + Azure Function pattern with private outbound networking.

## Architecture assumptions

- Start with Design A: Logic App Consumption calls Function over public HTTPS using function auth.
- Function outbound traffic uses delegated subnet integration (Microsoft.App/environments).
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
