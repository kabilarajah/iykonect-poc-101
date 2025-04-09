# Resource Group Configuration
variable "resource_group_name" {
  type        = string
  description = "Name of the resource group for the three-tier application"
  default     = "three-tier-app"  # Will be suffixed with environment
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region where resources will be deployed"
}

# Environment Configuration
variable "environment" {
  type        = string
  description = "Environment (PRD/DEV/QA)"
  validation {
    condition     = contains(["PRD", "DEV", "QA"], var.environment)
    error_message = "Environment must be PRD, DEV, or QA."
  }
}

# Common Tags
variable "common_tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "Three-Tier-App"
  }
}

# Domain Configuration
variable "domain_name" {
  type        = string
  description = "Domain name for the application (required)"
}

# Resource Prefix
variable "resource_prefix" {
  type        = string
  default     = "iykonect"
  description = "Prefix for all resources"
}

# VM Scale Set Configuration
variable "vm_count" {
  type = object({
    PRD = object({
      min     = number
      max     = number
      desired = number
    })
    DEV = number
    QA  = number
  })
  default = {
    PRD = {
      min     = 2
      max     = 4
      desired = 2
    }
    DEV = 1
    QA  = 2
  }
  description = "VM instance counts. PRD uses on-demand instances, non-PRD uses spot instances."
}

variable "admin_username" {
  type        = string
  description = "Administrator username for the VMs"
  sensitive   = true
}

# Database Configuration
variable "sql_admin_username" {
  type        = string
  description = "SQL Server administrator username"
  sensitive   = true
}

variable "sql_admin_password" {
  type        = string
  description = "SQL Server administrator password"
  sensitive   = true
}

# Backend Configuration
variable "backend_resource_group" {
  type        = string
  default     = "terraform-state-rg"
  description = "Resource group for terraform backend storage"
}

variable "backend_storage_account" {
  type        = string
  default     = "iykonecttfstate"
  description = "Storage account name for terraform backend"
}

variable "backend_container" {
  type        = string
  default     = "tfstate"
  description = "Container name for terraform state files"
}

# Storage Configuration
variable "storage_share_quota" {
  type        = number
  default     = 100
  description = "Quota in GB for Azure Files share"
}

variable "storage_account_type" {
  type = map(string)
  default = {
    PRD = "Premium_LRS"
    DEV = "Standard_LRS"
    QA  = "Standard_LRS"
  }
  description = "Storage account types for each environment"
}

# VM Configuration
variable "vm_disk_size" {
  type        = number
  default     = 30
  description = "Size in GB for VM OS disks"
}

variable "vm_repair_grace_period" {
  type        = string
  default     = "PT30M"
  description = "Grace period for instance repairs"
}

variable "vm_sizes" {
  type = map(string)
  default = {
    PRD = "Standard_D4s_v3"  # 4 cores, 16GB RAM
    DEV = "Standard_D2s_v3"
    QA  = "Standard_D2s_v3"
  }
  description = "VM sizes for each environment"
}

variable "vm_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  description = "VM image reference configuration"
}

# Autoscale Configuration
variable "autoscale_cpu_high" {
  type        = number
  default     = 50
  description = "CPU percentage threshold for scaling out"
}

variable "autoscale_cpu_low" {
  type        = number
  default     = 30
  description = "CPU percentage threshold for scaling in"
}

variable "autoscale_cooldown" {
  type        = string
  default     = "PT5M"
  description = "Cooldown period between scaling actions"
}
