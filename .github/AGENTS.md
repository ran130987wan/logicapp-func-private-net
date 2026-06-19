# Multi-Agent Structure for This POC

This repository uses specialized agents and reusable skills to run the Logic App + Function + Terraform proof of concept from scratch.

## Actual POC Requirement

- Build private-oriented Azure infrastructure for Logic App + Function execution.
- Use private execution defaults in Terraform workflows via `infra/environments/dev/terraform.private.tfvars`.
- Keep the scheduler requirement intact: one Function endpoint should still handle three schedule-driven invocations.
- Current Terraform still uses `azurerm_logic_app_workflow` (Consumption); full private inbound for Logic App requires migration to Logic App Standard with VNet integration.

## Agent Roles

- Execute Bootstrap Agent
  - Installs/checks prerequisites and runs local bootstrap.
- Execute Infra Agent
  - Runs Terraform fmt/init/validate/plan/apply (apply only with explicit approval).
- Execute Function Agent
  - Restores/builds/runs function app and executes local smoke tests.
- Execute POC Agent
  - Orchestrates full end-to-end execution with checkpoints.
- Execute Local POC Agent
  - Implements the full POC from a local machine and runs bootstrap, build, infra validate/plan, and governance checks.
- Execute Governance Agent
  - Validates execution controls, approvals, and compliance guardrails.
- Plan Infra Agent
  - Plans and scopes infrastructure changes before execution.

## Skills

- poc-bootstrap
  - Reusable install/check/bootstrap workflow for Linux Codespaces.
- poc-infra
  - Reusable Terraform execution policy and command flow.
- poc-function
  - Reusable function build and local validation flow.
- poc-e2e
  - Reusable end-to-end orchestration runbook.
- poc-governance
  - Reusable governance and compliance validation runbook.

## Orchestration Pattern

1. Run Execute Bootstrap Agent with skill poc-bootstrap.
2. Run Plan Infra Agent for change analysis (optional when no infra change).
3. Run Execute Infra Agent with skill poc-infra.
4. Run Execute Function Agent with skill poc-function.
5. Run Execute POC Agent with skill poc-e2e to verify complete status.
6. Run Execute Governance Agent with skill poc-governance before production-facing apply.

Local-first option:

1. Run Execute Local POC Agent when user asks to implement or validate the POC from local machine now.

## Safety Defaults

- Never run terraform apply without explicit user approval.
- Skip terraform plan when az login is missing.
- Do not store secrets in repository files.
- Prefer minimal, incremental edits.

## Memory Tuning

- Before writing new notes, inspect /memories/repo/ and update existing files when possible.
- Store durable repository facts in /memories/repo/setup-notes.md.
- Use /memories/session/ only for temporary per-conversation checkpoints.
- Keep memory entries concise and actionable to reduce repeated troubleshooting.
