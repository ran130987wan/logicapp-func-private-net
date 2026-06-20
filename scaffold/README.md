# POC Scaffold Kit

Use this scaffold kit to bootstrap a new repository that follows the same delivery pattern as this project:

- Terraform-based infra
- Azure Function app
- Logic App schedules calling one endpoint
- GitHub workflows and governance checks
- Copilot agents + skills for repeatable execution

## Quick start

1. Create a new repository folder.
2. Copy the template tree under scaffold/templates into the new repository.
3. Replace placeholder values (`demo`, `dev`, `weu`) with environment values.
4. Add GitHub secrets:
   - AZURE_CLIENT_ID
   - AZURE_TENANT_ID
   - AZURE_SUBSCRIPTION_ID
5. Run the first Terraform apply without `function_host_key` to create infra and workflows.
6. Deploy function code, retrieve the host key, then re-apply Terraform with `function_host_key` to add Logic App HTTP actions.
7. Open PR and ensure required checks pass.

## Template contents

- templates/.github/agents/execute-infra.agent.md
- templates/.github/skills/poc-infra/SKILL.md
- templates/.github/workflows/infra.yml
- templates/.github/workflows/poc-three-trigger.yml
- templates/infra/variables.tf
- templates/infra/logicapp.tf
- templates/docs/IMPLEMENTATION-INSTRUCTIONS.md

## Recommended rollout order

1. Land templates and CI first.
2. Add infra resources incrementally.
3. Add function endpoint and local tests.
4. Document the two-step host-key wiring flow before first apply.
5. Add trigger/log validation automation.
6. Add destroy/teardown process before first apply.
