#!/usr/bin/env bash
set -euo pipefail

# Prefer system-installed dotnet/runtime when available.
export PATH="/usr/bin:$PATH"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is not installed"
  exit 1
fi

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet is not installed"
  exit 1
fi

if ! command -v func >/dev/null 2>&1; then
  echo "Azure Functions Core Tools (func) is not installed"
  exit 1
fi

echo "Formatting and validating Terraform"
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init -upgrade
terraform -chdir=infra validate

if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
  echo "Azure CLI login detected. Running terraform plan."
  terraform -chdir=infra plan -var-file=environments/dev/terraform.tfvars -out=tf.plan
else
  echo "Azure login not detected. Skipping terraform plan (run 'az login' first)."
fi

echo "Restoring .NET dependencies"
dotnet restore src/MaintenanceApp/MaintenanceApp.csproj

echo "Bootstrap complete"
