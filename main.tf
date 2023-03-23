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
# Azure: Postgresql Database
###############

resource "azurerm_postgresql_server" "postgresql-server" {
  name                         = "pgsql-serv-1"
  location                     = azurerm_resource_group.TPAzureGroup.location
  resource_group_name          = azurerm_resource_group.TPAzureGroup.name
  sku_name                     = "GP_Gen5_4"
  version                      = "11"
  storage_mb                   = 640000  
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true
  
  administrator_login          = data.azurerm_key_vault_secret.postgres-username.value
  administrator_login_password = data.azurerm_key_vault_secret.postgres-password.value
  ssl_enforcement_enabled      = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

resource "azurerm_postgresql_firewall_rule" "pgsql-firewall-rule" {
  name                = "AllowAzureServices"
  resource_group_name = azurerm_resource_group.TPAzureGroup.name
  server_name         = azurerm_postgresql_server.postgresql-server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
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
      node_version = "16-lts"
    }
  }
}

###############
# PGAdmin : Container Instance
###############
resource "azurerm_container_group" "PGAdmin" {
  name                = "aci-pgadmin-${var.projectName}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-vclarke.name
  location            = data.azurerm_resource_group.rg-vclarke.location
  ip_address_type     = "Public"
  dns_name_label      = "aci-pgadmin-${var.projectName}${var.environment_suffix}"
  os_type             = "Linux"

  container {
    name   = "pgadmin"
    image  = "dpage/pgadmin4"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      "PGADMIN_DEFAULT_EMAIL" = data.azurerm_key_vault_secret.pgadmin-username.value,
      "PGADMIN_DEFAULT_PASSWORD" = data.azurerm_key_vault_secret.pgadmin-password.value
    }
  }
}

###############
# API : Container Instance
###############
resource "azurerm_container_group" "api" {
  name                = "aci-api-${var.projectName}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-vclarke.name
  location            = data.azurerm_resource_group.rg-vclarke.location
  ip_address_type     = "None"
  dns_name_label      = "aci-api-${var.projectName}${var.environment_suffix}"
  os_type             = "Linux"

  container {
    name   = "nodeapi"
    image  = "greugreu/nodeapi:1.0.4"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      DB_HOST: azurerm_postgresql_server.postgresql-server.fqdn
      DB_USERNAME = "${data.azurerm_key_vault_secret.postgres-username.value}@${azurerm_postgresql_server.postgresql-server.name}"
      DB_PASSWORD: data.azurerm_key_vault_secret.postgres-password.value
      DB_DATABASE: azurerm_postgresql_database.postgresql-database.name
      DB_DAILECT: "postgres"
      DB_PORT: 5432
      DATABASE_URL: "postgres://${data.azurerm_key_vault_secret.postgres-username.value}:${data.azurerm_key_vault_secret.postgres-password.value}@postgres:5432/${azurerm_postgresql_database.postgresql-database.name}"
      NODE_ENV: "development"
      PORT: 3000
    }
  }
}