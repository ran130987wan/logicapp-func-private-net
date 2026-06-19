# GitHub Tools and Automation

This folder documents the CI/CD toolchain used in this repository.

## Workflows

- .github/workflows/infra.yml: applies Terraform infrastructure changes.
- .github/workflows/deploy-func.yml: builds and deploys the Azure Function app.
- .github/workflows/validate.yml: validates Terraform and function build on pull requests.
- .github/workflows/poc-three-trigger.yml: validates single-function three-trigger behavior on pull requests.

## Agents

- .github/agents/plan-infra.agent.md: planning and impact analysis for infra changes.
- .github/agents/execute-bootstrap.agent.md: local bootstrap execution and fixes.
- .github/agents/execute-infra.agent.md: Terraform execution flow for environment tfvars.
- .github/agents/execute-function.agent.md: function app build/run execution flow.
- .github/agents/execute-poc.agent.md: end-to-end POC execution orchestration.
- .github/agents/execute-local-poc.agent.md: local-machine-first end-to-end POC implementation and validation.
- .github/agents/execute-governance.agent.md: governance compliance and policy execution checks.

## Skills

- .github/skills/poc-bootstrap/SKILL.md: from-scratch tool install and bootstrap flow.
- .github/skills/poc-infra/SKILL.md: Terraform execution workflow and apply policy.
- .github/skills/poc-function/SKILL.md: function build/run/smoke-test workflow.
- .github/skills/poc-e2e/SKILL.md: stage-based full POC execution workflow.
- .github/skills/poc-governance/SKILL.md: policy, approvals, and governance control validation workflow.

## Orchestration

- .github/AGENTS.md: multi-agent orchestration map for this POC.
- .github/prompts/run-poc-dispatcher.prompt.md: routes requests to the correct agent and skill.

## Governance

- docs/GOVERNANCE.md: execution controls, apply approval policy, scheduler governance, and test policy.
- development/scripts/verify-governance.sh: read-only validation of branch protection and required checks.

## Required repository settings

- Add secrets:
  - AZURE_CLIENT_ID
  - AZURE_TENANT_ID
  - AZURE_SUBSCRIPTION_ID
- Configure branch protection for `main`:
  - Require pull request before merge
  - Require at least 1 approval
  - Require status checks: `validate`, `three-trigger-test`
  - Require branch to be up to date before merge
  - For private repositories, branch protection requires GitHub Pro; on free plans, make the repository public first

## Memory-aware operations

- Keep persistent repo execution learnings in /memories/repo/setup-notes.md.
- Keep temporary task notes in /memories/session/ only for active conversations.
- Agent definitions should include memory usage guidance to avoid repeating known fixes.

## Optional hardening

- Add a GitHub environment (for example dev) and bind jobs to it.
- Add environment protection rules for main branch deployments.
- Split terraform plan and apply into separate jobs with approval gates.
