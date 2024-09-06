terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription-id
  client_id = var.client-id
  client_secret = var.client-secret
  tenant_id = var.tenant-id
  features {}
}

resource "azurerm_resource_group" "rg_new_resource" {
  location = var.location
  name     = "az-rg-group2"
}

resource "azurerm_mssql_server" "app_db_server" {
  name                         = "az-tf-app-db-sqlserver"
  resource_group_name          = azurerm_resource_group.rg_new_resource.name
  location                     = azurerm_resource_group.rg_new_resource.location
  version                      = "12.0"
  administrator_login          = "dbadmin"
  administrator_login_password = "Sql@Azure123$"
}

resource "azurerm_mssql_database" "ms_appdb" {
  name           = "app-db"
  server_id      = azurerm_mssql_server.app_db_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 1
  sku_name       = "Basic"
  depends_on = [azurerm_mssql_server.app_db_server]

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_mssql_firewall_rule" "app_firewall" {
  name             = "app-server-firewall-rule"
  server_id        = azurerm_mssql_server.app_db_server.id
  start_ip_address = "10.0.17.62"
  end_ip_address   = "10.0.17.62"
}

resource "null_resource" "db_setup" {
  provisioner "local-exec" {
    command = "sqlcmd -S az-tf-app-db-sqlserver.database.windows.net -U dbadmin -P Sql@Azure123$ -d app-db -i data.sql"
  }
  depends_on = [azurerm_mssql_server.app_db_server]
}