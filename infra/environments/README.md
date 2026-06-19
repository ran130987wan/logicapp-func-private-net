# Terraform Environments

Keep environment-specific tfvars files in this folder.

- dev/terraform.tfvars: active development values
- prod/terraform.tfvars.example: production template

Usage:

- terraform -chdir=infra plan -var-file=environments/dev/terraform.tfvars
- terraform -chdir=infra apply -var-file=environments/dev/terraform.tfvars
