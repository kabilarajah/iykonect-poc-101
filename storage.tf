# Storage Architecture Overview:
# - Standard LRS storage account
# - Azure Files share for persistent storage
# - Mounted at /apps on all VMSS instances
# - Protected from accidental deletion

# Storage Account Configuration
# Application Storage Account
# Used for shared storage across VMSS instances
resource "azurerm_storage_account" "apps" {
  name                     = "${var.resource_prefix}${lower(var.environment)}apps"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location

  # Standard tier with local redundancy for cost optimization
  account_tier            = "Standard"
  account_replication_type = "LRS"

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "application-storage"
  })

  # Prevent accidental deletion of shared storage
  lifecycle {
    prevent_destroy = true
  }
}

# File Share Configuration
# - 100GB quota
# - CIFS/SMB3 protocol
# - Mounted with read-write access
# Azure Files Share Configuration
# Provides persistent storage mounted to all VMSS instances
resource "azurerm_storage_share" "apps" {
  name                 = "applications"
  storage_account_name = azurerm_storage_account.apps.name

  # 100GB quota as defined in variables
  quota                = var.storage_share_quota

  # Prevent accidental deletion of shared files
  lifecycle {
    prevent_destroy = true
  }
}
