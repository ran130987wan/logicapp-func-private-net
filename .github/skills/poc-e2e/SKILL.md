---
name: poc-e2e
description: "Use when running the complete POC execution from bootstrap through infra/function validation with stage-by-stage status."
---

# POC End-to-End Skill

## Purpose

Provide one repeatable workflow for full POC execution and status reporting.

## Stage checklist

1. Bootstrap stage
   - ./development/scripts/bootstrap.sh
2. Function stage
   - dotnet build src/MaintenanceApp/MaintenanceApp.csproj -c Release
3. Infra validate stage
   - terraform -chdir=infra init -backend=false
   - terraform -chdir=infra validate
4. Infra plan stage (if authenticated)
   - terraform -chdir=infra plan -var-file=environments/dev/terraform.tfvars

## Output format

- Stage name
- Pass/fail
- Error summary
- Fix applied or required next action

## Guardrails

- Do not apply infrastructure without explicit user request.
- Keep changes minimal and rerun only failed stage after each fix.

## Memory guidance

- Capture reusable stage outcomes and blockers in /memories/repo/setup-notes.md.
