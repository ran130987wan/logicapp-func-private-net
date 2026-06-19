---
name: poc-infra
description: "Use when executing Terraform for this POC with environment-scoped tfvars and controlled apply behavior."
---

# POC Infra Skill

## Purpose

Execute infrastructure commands consistently and safely.

## Standard flow

```bash
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init
terraform -chdir=infra validate
terraform -chdir=infra plan -var-file=environments/dev/terraform.private.tfvars
```

## Apply policy

- Only run apply after explicit user confirmation.
- Commands:

```bash
terraform -chdir=infra apply -var-file=environments/dev/terraform.private.tfvars
```

```bash
terraform -chdir=infra apply -var-file=environments/dev/terraform.private.tfvars -var "function_host_key=<HOST_KEY>"
```

- First apply creates infra and workflows.
- After function deployment, retrieve the host key and run the second apply to add Logic App `CallFunction` actions.

## Cost baseline

- Keep POC on low-cost defaults: Function max scale cap, short log retention, and Consumption Logic App resources.
- Avoid premium or always-on alternatives unless explicitly requested.

## Auth prerequisites

If plan/apply fails due to auth, run:

```bash
az login --tenant b52aa991-8ac7-4b6c-8bc9-03fb21d0d4ac
az account set --subscription cf83455a-73e2-41b7-b28b-fbbf1467713d
```

## Memory guidance

- Record recurring Terraform/auth constraints in /memories/repo/setup-notes.md.
