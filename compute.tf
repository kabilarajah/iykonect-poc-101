# Compute Architecture Overview:
# PRD Environment:
# - On-demand instances for reliability
# - Higher spec VMs (4 cores, 16GB RAM)
# - Premium storage for better performance
# - Protected from scale-in events
#
# DEV/QA Environments:
# - Spot instances for cost optimization
# - Standard VMs (2 cores, 8GB RAM)
# - Standard storage
# - Automatic scale-in/out based on CPU

locals {
  vm_sizes = {
    PRD = "Standard_D4s_v3"  # 4 cores, 16GB RAM
    DEV = "Standard_D2s_v3"
    QA  = "Standard_D2s_v3"
  }

  storage_account_type = {
    PRD = "Premium_LRS"
    DEV = "Standard_LRS"
    QA  = "Standard_LRS"
  }
}

# Production VMSS Configuration
resource "azurerm_linux_virtual_machine_scale_set" "vmss_prd" {
  count               = var.environment == "PRD" ? 1 : 0
  name                = "${var.resource_prefix}-${var.environment}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vm_sizes.PRD
  instances           = var.vm_count.PRD.desired
  admin_username      = var.admin_username

  priority            = "Regular"

  # Ensure instances are protected from scale-in operations
  scale_in {
    rule = "ProtectNewVMs"  # Protects newly created instances from being scaled in
  }

  # OS configuration using Ubuntu 18.04 LTS
  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  # Mount Azure Files for persistent storage
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    storage_account  = azurerm_storage_account.apps.name
    storage_key      = azurerm_storage_account.apps.primary_access_key
    share_name       = azurerm_storage_share.apps.name
  }))

  # Premium storage for production workloads
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type[var.environment]
    disk_size_gb         = var.vm_disk_size
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name                                    = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bp.id]
    }
  }

  # Enable automatic repairs and upgrades for high availability
  automatic_instance_repair {
    enabled      = true
    grace_period = var.vm_repair_grace_period
  }

  dynamic "automatic_os_upgrade_policy" {
    for_each = var.environment == "PRD" ? [1] : []
    content {
      enable_automatic_os_upgrade = true
      disable_automatic_rollback  = false
    }
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "application-compute"
  })
}

# Non-Production VMSS Configuration
# Optimized for cost using spot instances
resource "azurerm_linux_virtual_machine_scale_set" "vmss_nonprod" {
  count               = var.environment != "PRD" ? 1 : 0
  name                = "${var.resource_prefix}-${var.environment}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vm_sizes[var.environment]
  instances           = var.vm_count[var.environment]
  admin_username      = var.admin_username

  # Configure spot instance behavior
  priority            = "Spot"
  eviction_policy     = "Delete"  # Instances will be deleted when evicted

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    storage_account  = azurerm_storage_account.apps.name
    storage_key      = azurerm_storage_account.apps.primary_access_key
    share_name       = azurerm_storage_share.apps.name
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type[var.environment]
    disk_size_gb         = var.vm_disk_size
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name                                    = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bp.id]
    }
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }

  dynamic "automatic_os_upgrade_policy" {
    for_each = var.environment != "PRD" ? [1] : []
    content {
      enable_automatic_os_upgrade = true
      disable_automatic_rollback  = false
    }
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "application-compute"
  })
}

# Auto-scaling Configuration
# Rules:
# - Scale out when CPU > 50% for 5 minutes
# - Scale in when CPU < 30% for 5 minutes
# - 5 minute cooldown between scaling events
resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "${var.resource_prefix}-${var.environment}-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = var.environment == "PRD" ? azurerm_linux_virtual_machine_scale_set.vmss_prd[0].id : azurerm_linux_virtual_machine_scale_set.vmss_nonprod[0].id
  location            = var.location

  profile {
    name = "AutoScale"

    capacity {
      default = var.environment == "PRD" ? var.vm_count.PRD.desired : var.vm_count[var.environment]
      minimum = var.environment == "PRD" ? var.vm_count.PRD.min : 1
      maximum = var.environment == "PRD" ? var.vm_count.PRD.max : 4
    }

    # Scale out when CPU > 50% for 5 minutes
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.environment == "PRD" ? azurerm_linux_virtual_machine_scale_set.vmss_prd[0].id : azurerm_linux_virtual_machine_scale_set.vmss_nonprod[0].id
        time_grain        = "PT1M"
        statistic         = "Average"
        time_window      = "PT5M"
        time_aggregation = "Average"
        operator         = "GreaterThan"
        threshold        = var.autoscale_cpu_high
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = var.autoscale_cooldown
      }
    }

    # Scale in when CPU < 30% for 5 minutes
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.environment == "PRD" ? azurerm_linux_virtual_machine_scale_set.vmss_prd[0].id : azurerm_linux_virtual_machine_scale_set.vmss_nonprod[0].id
        time_grain        = "PT1M"
        statistic         = "Average"
        time_window      = "PT5M"
        time_aggregation = "Average"
        operator         = "LessThan"
        threshold        = var.autoscale_cpu_low
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
