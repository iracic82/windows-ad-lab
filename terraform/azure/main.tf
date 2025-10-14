# ============================================================================
# Azure Windows Active Directory Lab - Main Configuration
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }

  subscription_id = var.azure_subscription_id
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Calculate private IPs for DCs (starting from .5)
  dc_private_ips = [
    for idx in range(var.domain_controller_count) :
    cidrhost(var.azure_dc_subnet_cidr, 5 + idx)
  ]

  # Calculate private IPs for clients (starting after DCs)
  client_private_ips = [
    for idx in range(var.client_count) :
    cidrhost(var.azure_client_subnet_cidr, 5 + idx)
  ]
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.azure_location

  tags = local.common_tags
}

# ============================================================================
# Networking Module
# ============================================================================

module "azure_networking" {
  source = "./modules/azure-networking"

  project_name        = var.project_name
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.main.name

  # Control whether to create new or use existing VNets
  use_existing = var.azure_use_existing_vnets

  # For creating NEW VNets
  dc_vnet_cidr       = var.azure_dc_vnet_cidr
  dc_subnet_cidr     = var.azure_dc_subnet_cidr
  client_vnet_cidr   = var.azure_client_vnet_cidr
  client_subnet_cidr = var.azure_client_subnet_cidr

  # For using EXISTING VNets
  existing_resource_group_name = var.azure_existing_resource_group_name
  existing_dc_vnet_name        = var.azure_existing_dc_vnet_name
  existing_dc_subnet_name      = var.azure_existing_dc_subnet_name
  existing_client_vnet_name    = var.azure_existing_client_vnet_name
  existing_client_subnet_name  = var.azure_existing_client_subnet_name

  allowed_rdp_ips   = var.allowed_rdp_cidrs
  allowed_winrm_ips = var.allowed_winrm_cidrs

  common_tags = local.common_tags

  depends_on = [azurerm_resource_group.main]
}

# ============================================================================
# Domain Controllers
# ============================================================================

module "azure_domain_controllers" {
  source = "./modules/azure-windows-vm"
  count  = var.domain_controller_count

  project_name        = var.project_name
  name                = "dc${count.index + 1}"
  role                = "domain_controller"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.main.name
  vm_size             = var.azure_dc_vm_size
  windows_sku         = var.azure_windows_sku
  subnet_id           = module.azure_networking.dc_subnet_id
  private_ip          = local.dc_private_ips[count.index]
  admin_password      = var.domain_admin_password
  os_disk_size        = var.root_volume_size
  create_public_ip    = true
  common_tags         = local.common_tags

  depends_on = [module.azure_networking]
}

# ============================================================================
# Domain Clients
# ============================================================================

module "azure_clients" {
  source = "./modules/azure-windows-vm"
  count  = var.client_count

  project_name        = var.project_name
  name                = "client${count.index + 1}"
  role                = "domain_client"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.main.name
  vm_size             = var.azure_client_vm_size
  windows_sku         = var.azure_windows_sku
  subnet_id           = module.azure_networking.client_subnet_id
  private_ip          = local.client_private_ips[count.index]
  admin_password      = var.domain_admin_password
  dc1_ip              = local.dc_private_ips[0]
  os_disk_size        = var.root_volume_size
  create_public_ip    = true
  common_tags         = local.common_tags

  depends_on = [module.azure_networking]
}

# ============================================================================
# Ansible Inventory Module (reusing existing module)
# ============================================================================

module "azure_ansible_inventory" {
  source = "./modules/ansible-inventory"

  domain_controllers = [
    for idx in range(var.domain_controller_count) : {
      name       = module.azure_domain_controllers[idx].name
      public_ip  = module.azure_domain_controllers[idx].public_ip
      private_ip = module.azure_domain_controllers[idx].private_ip
    }
  ]

  clients = [
    for idx in range(var.client_count) : {
      name       = module.azure_clients[idx].name
      public_ip  = module.azure_clients[idx].public_ip
      private_ip = module.azure_clients[idx].private_ip
    }
  ]

  ansible_user      = var.ansible_user
  ansible_password  = var.domain_admin_password
  domain_name       = var.domain_name
  domain_netbios    = "CORP"
  domain_admin_user = "CORP\\${var.ansible_user}"
  output_path       = "../ansible/inventory/azure_windows.yml"

  depends_on = [
    module.azure_domain_controllers,
    module.azure_clients
  ]
}
