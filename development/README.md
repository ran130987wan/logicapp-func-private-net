# Development

This folder contains local developer tooling for this repository.

## Quick start

1. Copy infra/environments/dev/terraform.private.tfvars and update values for your subscription and backend.
2. Copy src/MaintenanceApp/local.settings.json.example to src/MaintenanceApp/local.settings.json.
3. Copy development/azure.env.example to development/azure.env and update if needed.
4. Source your environment file: `source development/azure.env`.
5. Run development/scripts/bootstrap.sh.
6. Run development/scripts/test-local-function.sh.
7. Run development/scripts/test-three-schedules.sh to validate 3 scheduler-style invocations.
8. Run development/scripts/verify-governance.sh to verify branch protection and required checks.
9. Run development/scripts/check-github-access.sh to diagnose GitHub admin/API access.
10. Run development/scripts/fix-repo-access.sh to apply branch protection (for private repositories, this requires GitHub Pro; on free plans, make the repository public first).
11. Run development/scripts/validate-trigger-logs.sh to trigger all workflows and collect Function log evidence.

## Notes

- Do not commit local.settings.json.
- Terraform state is local by default in this scaffold.
- Terraform variables are environment-scoped under infra/environments/.
- Use OIDC in GitHub Actions for Azure authentication.
- In Linux Codespaces, `bootstrap.sh` validates Terraform and only runs `terraform plan` after successful `az login`.
- Scripts prefer `/usr/bin` runtime path to avoid user-level .NET runtime mismatches.
- Keep reusable repo execution notes in /memories/repo/setup-notes.md.
