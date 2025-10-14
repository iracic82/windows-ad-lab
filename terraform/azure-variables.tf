# ============================================================================
# Azure Windows Active Directory Lab - Variables
# ============================================================================

# ===================================
# Azure Configuration
# ===================================

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "azure_location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

# ===================================
# Network Configuration
# ===================================

variable "azure_use_existing_vnets" {
  description = "Use existing VNets and subnets (true) or create new ones (false)"
  type        = bool
  default     = false
}

# --- Variables for CREATING new VNets (when azure_use_existing_vnets = false) ---

variable "azure_dc_vnet_cidr" {
  description = "CIDR block for DC VNet (used when creating new VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azure_dc_subnet_cidr" {
  description = "CIDR block for DC subnet (used when creating new VNet)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "azure_client_vnet_cidr" {
  description = "CIDR block for Client VNet (used when creating new VNet)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azure_client_subnet_cidr" {
  description = "CIDR block for Client subnet (used when creating new VNet)"
  type        = string
  default     = "10.1.1.0/24"
}

# --- Variables for USING existing VNets (when azure_use_existing_vnets = true) ---

variable "azure_existing_resource_group_name" {
  description = "Name of existing resource group containing VNets (required if using existing VNets)"
  type        = string
  default     = ""
}

variable "azure_existing_dc_vnet_name" {
  description = "Name of existing DC VNet (required if using existing VNets)"
  type        = string
  default     = ""
}

variable "azure_existing_dc_subnet_name" {
  description = "Name of existing DC subnet (required if using existing VNets)"
  type        = string
  default     = ""
}

variable "azure_existing_client_vnet_name" {
  description = "Name of existing Client VNet (required if using existing VNets)"
  type        = string
  default     = ""
}

variable "azure_existing_client_subnet_name" {
  description = "Name of existing Client subnet (required if using existing VNets)"
  type        = string
  default     = ""
}

# ===================================
# VM Configuration
# ===================================

variable "azure_dc_vm_size" {
  description = "Azure VM size for Domain Controllers"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "azure_client_vm_size" {
  description = "Azure VM size for client machines"
  type        = string
  default     = "Standard_B2s"
}

variable "azure_windows_sku" {
  description = "Windows Server SKU"
  type        = string
  default     = "2022-datacenter-g2"
}
