locals {
  schedules_by_name   = { for s in var.schedules : s.name => s }
  enable_function_call = length(nonsensitive(var.function_host_key)) > 0
}

resource "azurerm_logic_app_workflow" "schedule" {
  for_each            = local.schedules_by_name
  name                = "logic-${var.product}-${each.value.name}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_logic_app_trigger_recurrence" "schedule" {
  for_each     = azurerm_logic_app_workflow.schedule
  name         = "Recurrence"
  logic_app_id = each.value.id
  frequency    = local.schedules_by_name[each.key].frequency
  interval     = local.schedules_by_name[each.key].interval
}

resource "azurerm_logic_app_action_http" "call_function" {
  for_each     = local.enable_function_call ? azurerm_logic_app_workflow.schedule : {}
  name         = "CallFunction"
  logic_app_id = each.value.id
  method       = "POST"
  uri          = "https://${azurerm_function_app_flex_consumption.main.default_hostname}/api/jobs/execute${var.function_host_key != "" ? "?code=${var.function_host_key}" : ""}"

  headers = {
    Content-Type = "application/json"
  }

  body = jsonencode({
    JobName   = local.schedules_by_name[each.key].job_name
    TargetEnv = "CP-${var.environment}"
    ForceRun  = false
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.schedule]
}
