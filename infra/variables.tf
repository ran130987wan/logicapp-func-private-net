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
      interval  = 6
    }
  ]
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "logicapp-func-private-net"
    ManagedBy = "terraform"
  }
}
