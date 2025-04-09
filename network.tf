# Network Architecture Overview:
# - Virtual Network (10.0.0.0/16) for complete isolation
# - Web subnet (10.0.1.0/24) for application tier
# - Standard Load Balancer for high availability
# - DNS zone for custom domain management

# Virtual Network Configuration
# Creates isolated network space for each environment
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment}-app-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Large address space to accommodate future growth
  address_space       = ["10.0.0.0/16"]  # 65,534 available addresses

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "application-networking"
  })
}

# Subnet Configuration
# Dedicated subnet for application tier with:
# - Room for 254 instances
# - Support for VMSS auto-scaling
# - Load balancer backend pool integration
resource "azurerm_subnet" "web" {
  name                 = "${var.environment}-web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  # Subnet sized for up to 254 instances
  address_prefixes     = ["10.0.1.0/24"]  # 254 usable IPs
}

# DNS Configuration
# Manages custom domain for:
# - Application endpoints
# - Load balancer frontend
# - Future service discovery
resource "azurerm_dns_zone" "dns" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.rg.name

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "dns-management"
  })
}

# Load Balancer Configuration
# Standard SKU Load Balancer provides:
# - High Availability with SLA
# - Zone redundancy support
# - VMSS backend pool integration
# - Outbound rules management
resource "azurerm_lb" "lb" {
  name                = "${var.environment}-app-lb"
  location            = azurerm_resource_group_name.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Standard SKU provides SLA and is required for production
  sku                 = "Standard"  # Required for production workloads

  # Single frontend IP configuration for all traffic
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "load-balancing"
  })
}
