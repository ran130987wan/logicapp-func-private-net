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

variable "function_host_key" {
  description = "Optional function key used by Logic App HTTP action."
  type        = string
  default     = ""
  sensitive   = true
}

variable "schedules" {
  description = "One Logic App schedule per entry"
  type = list(object({
    name      = string
    job_name  = string
    frequency = string
    interval  = number
  }))
}
