---
name: poc-infra
description: "Terraform execution policy for this POC (fmt/init/validate/plan/apply/destroy)."
---

# POC Infra Skill

## Stage checklist

1. terraform -chdir=infra fmt -recursive
2. terraform -chdir=infra init
3. terraform -chdir=infra validate
4. terraform -chdir=infra plan -var-file=environments/dev/terraform.private.tfvars
5. terraform -chdir=infra apply -auto-approve tf.plan (only on explicit request)
6. terraform -chdir=infra destroy -auto-approve -var-file=environments/dev/terraform.private.tfvars (only on explicit request)

## Guardrails

- Do not run apply or destroy without explicit user confirmation.
- Do not store secrets in files.
- Keep environments isolated through tfvars files.

## Output format

- Stage name
- Pass/fail
- Error summary
- Next action
