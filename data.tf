data "azurerm_resource_group" "rg-vclarke" {
  name = "rg-${var.projectName}${var.environment_suffix}"
}

data "azurerm_key_vault" "kv" {
  name                = "kv-${var.projectName}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-vclarke.name
}

data "azurerm_key_vault_secret" "postgres-username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "postgres-username"
}

data "azurerm_key_vault_secret" "postgres-password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "postgres-password"
}

data "azurerm_key_vault_secret" "pgadmin-username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "pgadmin-username"
}

data "azurerm_key_vault_secret" "pgadmin-password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "pgadmin-password"
}