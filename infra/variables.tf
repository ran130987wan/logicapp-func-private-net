variable "subscription_id" {
  description = "Target Azure subscription ID"
  type        = string
}

variable "product" {
  type    = string
  default = "demo"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "short_region" {
  type    = string
  default = "weu"
}

variable "function_public_access" {
  description = "true = public inbound endpoint enabled"
  type        = bool
  default     = false
}

variable "target_backend_url" {
  description = "Private backend URL reached by the function app"
  type        = string
  default     = "https://your-cp-backend.internal"
}

variable "vault_api_url" {
  description = "Base URL of vault-api (Refit IVdvDataApi)."
  type        = string
  default     = "https://your-vault-api.internal"
}

variable "infra_api_url" {
  description = "Base URL of infra-api (Refit IInfrastructureApi)."
  type        = string
  default     = "https://your-infra-api.internal"
}

variable "function_maximum_instance_count" {
  description = "Maximum burst scale for Function Flex Consumption (lower keeps POC cost predictable)"
  type        = number
  default     = 20
}

variable "log_analytics_retention_days" {
  description = "Log Analytics retention for POC cost control"
  type        = number
  default     = 30
}

variable "schedules" {
  description = "One Logic App schedule per entry"
  type = list(object({
    name      = string
    job_name  = string
    frequency = string
    interval  = number
  }))
  default = [
    {
      name      = "expired-programs"
      job_name  = "UpcomingExpiredPrograms"
      frequency = "Day"
      interval  = 1
    },
    {
      name      = "weekly-cleanup"
      job_name  = "WeeklyExpiredCleanup"
      frequency = "Week"
      interval  = 1
    },
    {
      name      = "hourly-reconcile"
      job_name  = "HourlyReconciliation"
      frequency = "Hour"
      interval  = 12
    }
  ]
}

variable "function_host_key" {
  description = "Function app host key for Logic App → Function auth. Supply after function deploy, then re-apply Terraform to add the HTTP action. Leave empty to create workflows without wiring the function call yet."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "logicapp-func-private-net"
    ManagedBy = "terraform"
  }
}
