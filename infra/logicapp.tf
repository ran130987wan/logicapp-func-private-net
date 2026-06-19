# Logic App HTTP action calls the function endpoint.
# If function_host_key is supplied, it will be appended as a query param for Function-level auth.
# Leave function_host_key empty for development/testing; retrieve it post-deploy with:
# az rest --method POST --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<func>/host/default/listkeys?api-version=2022-03-01" --query "functionKeys.default" -o tsv
locals {
  schedules_by_name = { for s in var.schedules : s.name => s }
}

resource "azurerm_logic_app_workflow" "schedule" {
  for_each            = local.schedules_by_name
  name                = "logic-${var.product}-${each.value.name}-${var.environment}-${var.short_region}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_logic_app_trigger_recurrence" "schedule" {
  for_each     = azurerm_logic_app_workflow.schedule
  name         = "Recurrence"
  logic_app_id = each.value.id
  frequency    = local.schedules_by_name[each.key].frequency
  interval     = local.schedules_by_name[each.key].interval
}

resource "azurerm_logic_app_action_http" "call_function" {
  for_each     = azurerm_logic_app_workflow.schedule
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
