terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }

  backend "azurerm" {

  }
}

provider "azurerm" {
  # configuration options
  features {}
}

###############
# Azure: Resource Group && Service
###############

resource "azurerm_resource_group" "TPAzureGroup" {
  location = var.location
  name     = "rg-${var.projectName}${var.environment_suffix}"
}

resource "azurerm_service_plan" "AzurermServicePlan" {
  name                = "${var.projectName}${var.environment_suffix}-Plan"
  resource_group_name = azurerm_resource_group.TPAzureGroup.name
  location            = azurerm_resource_group.TPAzureGroup.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

###############
# Azure: Database
###############

resource "azurerm_postgresql_server" "postgresql-server" {
  name                = "postgresql-server-1"
  location            = azurerm_resource_group.TPAzureGroup.location
  resource_group_name = azurerm_resource_group.TPAzureGroup.name

  sku_name = "B_Gen5_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = data.azurerm_key_vault_secret.postgres-username.value
  administrator_login_password = data.azurerm_key_vault_secret.postgres-password.value
  version                      = "9.5"
  ssl_enforcement_enabled      = true
}


resource "azurerm_mssql_firewall_rule" "postgresql-rule" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_server.postgresql-server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_database" "postgresql-database" {
  name                = "postgresql-database"
  resource_group_name = azurerm_resource_group.TPAzureGroup.name
  server_name         = azurerm_postgresql_server.postgresql-server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

###############
# Azure: WebApp
###############

resource "azurerm_linux_web_app" "AzurermWebApp" {
  name                = "web-${var.projectName}${var.environment_suffix}"
  resource_group_name = azurerm_resource_group.TPAzureGroup.name
  location            = azurerm_resource_group.TPAzureGroup.location
  service_plan_id     = azurerm_service_plan.AzurermServicePlan.id
  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
  }

  connection_string {
    name = "DefaultConnection"
    value = "Server=tcp:${azurerm_mssql_server.sql-srv.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sql-db.name};Persist Security Info=False;User ID=${data.azurerm_key_vault_secret.database-username.value};Password=${data.azurerm_key_vault_secret.database-password.value};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    type = "SQLAzure"
  }
}