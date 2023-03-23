output "main-rg-name" {
  value = azurerm_resource_group.TPAzureGroup.name
}
output "main-rg-id" {
  value = azurerm_resource_group.TPAzureGroup.id
}

output "resource-group-count" {
  value     = length(data.azurerm_resource_group.rg-vclarke)
}

output "resource-group-location" {
  value = data.azurerm_resource_group.rg-vclarke.location
}
