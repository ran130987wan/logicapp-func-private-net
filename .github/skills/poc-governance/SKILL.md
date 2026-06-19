---
name: poc-governance
description: "Use when validating governance controls, execution policy, and release guardrails for this POC."
---

# POC Governance Skill

## Purpose

Validate that execution follows policy, approval controls, and documented guardrails.

## Checks

1. Apply approval control
   - Confirm Terraform apply is never run without explicit user approval.
2. Secrets control
   - Confirm no secrets are committed to repository files.
3. Environment control
   - Confirm env-scoped tfvars under infra/environments/.
   - Confirm private execution profile (`environments/dev/terraform.private.tfvars`) is used by infra workflow defaults.
4. Test control
   - Confirm three-schedule local invocation test exists and passes when host is running.

## Enforcement references

- docs/GOVERNANCE.md
- .github/AGENTS.md
- .github/workflows/

## Output format

- Control name
- Status (Pass/Fail)
- Evidence file/command
- Remediation action

## Memory guidance

- Persist confirmed governance edge cases in /memories/repo/setup-notes.md.
