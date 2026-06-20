output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "function_app_name" {
  value = azurerm_function_app_flex_consumption.main.name
}

output "function_app_hostname" {
  value = azurerm_function_app_flex_consumption.main.default_hostname
}

output "logic_app_names" {
  value = [for item in azurerm_logic_app_workflow.schedule : item.name]
}
