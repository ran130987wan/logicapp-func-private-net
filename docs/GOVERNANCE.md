# POC Governance and Execution Policy

## Scope

This policy governs execution of the Logic App + Function + Terraform proof of concept.

## Change Control

- All infrastructure changes must run terraform validate before plan.
- Terraform apply requires explicit user approval.
- Environment-scoped variables must remain under infra/environments/.

## Security and Secrets

- No secrets in repository files.
- Use Azure login and OIDC for authenticated operations.
- Keep function key usage limited to POC; prefer managed identity for hardening.

## Operational Guardrails

- Bootstrap execution is allowed without Azure login.
- Terraform plan/apply require Azure login with correct tenant and subscription.
- Retry failed stage only; avoid rerunning full pipeline unnecessarily.
- In mixed .NET environments, prefer system runtime path (`/usr/bin`) to ensure net8 function compatibility.

## Scheduler Governance

- Requirement: one Azure Function endpoint must support multiple Logic App schedules.
- Baseline POC uses three schedules:
  - UpcomingExpiredPrograms
  - WeeklyExpiredCleanup
  - HourlyReconciliation
- Each schedule maps to a separate Logic App workflow posting to the same function route.

## Test Policy

- Local validation must include three sequential scheduler-style invocations.
- Command: development/scripts/test-three-schedules.sh
- POC is considered valid when all three invocations return status Success.
- Pull requests must pass .github/workflows/poc-three-trigger.yml for automated enforcement.

## Branch Protection and Required Checks

Protect the `main` branch with required status checks.

Required checks:

- `validate` (from `.github/workflows/validate.yml`)
- `three-trigger-test` (from `.github/workflows/poc-three-trigger.yml`)

Recommended protection settings:

- Require a pull request before merging.
- Require approvals (at least 1).
- Require status checks to pass before merging.
- Require branches to be up to date before merging.
- Restrict direct pushes to `main`.

Optional GitHub CLI automation:

```bash
./development/scripts/fix-repo-access.sh
```

Notes:

- For private repositories, branch protection requires GitHub Pro.
- On free plans, make the repository public, then run the script.

Read-only policy verification command:

```bash
./development/scripts/verify-governance.sh
```

Access diagnostics and remediation:

```bash
./development/scripts/check-github-access.sh
./development/scripts/fix-repo-access.sh
```

## Tested Evidence (Current POC)

- Local host endpoint: http://localhost:7071/api/jobs/execute
- Three successful invocations observed for:
  - UpcomingExpiredPrograms
  - WeeklyExpiredCleanup
  - HourlyReconciliation
- Result: PASS, single function accepted 3 scheduler-style invocations.
