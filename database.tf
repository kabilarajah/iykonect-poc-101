# Database Architecture Overview:
# PRD Environment:
# - Standard tier for production workloads
# - Higher performance and storage limits
# - Full SLA coverage
#
# DEV/QA Environments:
# - Basic tier for cost optimization
# - Limited performance for testing
# - Minimal SLA requirements

# Database SKU configuration per environment
# PRD uses Standard tier, DEV and QA use Basic tier
locals {
  db_sku = {
    PRD = "Standard"
    DEV = "Basic"
    QA  = "Basic"
  }
  db_name = "${var.environment}-app-database"
}

# SQL Server Configuration
# - Version 12.0 (latest stable)
# - Admin authentication
# - Deletion protection enabled
resource "azurerm_mssql_server" "sql" {
  name                         = "${var.environment}-sql-server"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  version                     = "12.0"
  administrator_login         = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database"
  })

  # Prevent accidental deletion of production database
  lifecycle {
    prevent_destroy = true
  }
}

# Database Configuration
# - Environment-specific SKUs
# - Standard collation
# - Included license model
# - Deletion protection
resource "azurerm_mssql_database" "db" {
  name           = local.db_name
  server_id      = azurerm_mssql_server.sql.id
  
  # Default collation for standard SQL operations
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  
  # Use included license to avoid additional licensing costs
  license_type   = "LicenseIncluded"
  
  # SKU based on environment (Standard for PRD, Basic for others)
  sku_name       = local.db_sku[var.environment]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "database"
  })

  # Prevent accidental deletion of database
  lifecycle {
    prevent_destroy = true
  }
}
