# Terraform Environments

Keep environment-specific tfvars files in this folder.

- dev/terraform.tfvars: active development values
- dev/terraform.private.tfvars: private-infra development values (Function public access disabled)
- prod/terraform.tfvars.example: production template

Cost-aware defaults in dev profiles:

- `function_maximum_instance_count` keeps Flex Consumption burst limits conservative.
- `log_analytics_retention_days` uses Azure minimum supported retention (30 days) for lowest valid POC baseline.

Usage:

- terraform -chdir=infra plan -var-file=environments/dev/terraform.tfvars
- terraform -chdir=infra apply -var-file=environments/dev/terraform.tfvars
- terraform -chdir=infra plan -var-file=environments/dev/terraform.private.tfvars
- terraform -chdir=infra apply -var-file=environments/dev/terraform.private.tfvars
