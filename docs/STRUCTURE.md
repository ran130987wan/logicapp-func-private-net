# Repository Structure

This project is split by concern so infrastructure, application code, and automation are isolated.

## Top-level folders

- infra/: Terraform root for Azure resources.
- src/: Azure Function source code.
- development/: local developer scripts and environment templates.
- .github/workflows/: CI/CD pipelines.
- .github/agents/: custom GitHub Copilot agent definitions.
- .github/prompts/: reusable prompt templates.
- .github/tools/: automation and workflow documentation.
- /memories/repo/: repository-scoped execution memory and operational notes.
- /memories/session/: temporary session-scoped memory.

## Terraform layout

- infra/main.tf, infra/network.tf, infra/function.tf, infra/logicapp.tf: resource definitions.
- infra/variables.tf, infra/outputs.tf: shared interface.
- infra/environments/dev/terraform.tfvars: development environment values.
- infra/environments/prod/terraform.tfvars.example: production template.

## Development layout

- src/MaintenanceApp/: C# isolated worker function app.
- development/scripts/bootstrap.sh: setup and validation for local dev.
- development/scripts/test-local-function.sh: local HTTP smoke test.

## GitHub automation layout

- .github/workflows/infra.yml: Terraform plan/apply deployment.
- .github/workflows/deploy-func.yml: function build and deploy.
- .github/workflows/validate.yml: PR validation checks.

## Memory layout

- /memories/repo/setup-notes.md: stable repo setup and troubleshooting facts.
- /memories/session/: transient notes used only during the active conversation.
