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
# Project Configuration
# ===================================

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "windows-ad-lab"
}

variable "vm_name_prefix" {
  description = "Short prefix for VM names (e.g., 'winadlab' for winadlab-dc1)"
  type        = string
  default     = "winadlab"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "managed_by" {
  description = "Tool or system managing these resources"
  type        = string
  default     = "Terraform"
}

variable "creator" {
  description = "Email of the person who created these resources"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Email of the resource owner"
  type        = string
  default     = ""
}

variable "purpose" {
  description = "Purpose of the deployment"
  type        = string
  default     = "SalesEnablement"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Enablement-Labs"
}

variable "department" {
  description = "Department owning these resources"
  type        = string
  default     = "SolutionArchitecture"
}

variable "lifecycle" {
  description = "Resource lifecycle (Persistent, Temporary, Ephemeral)"
  type        = string
  default     = "Persistent"
}

# ===================================
# Domain Configuration
# ===================================

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "corp.infolab"
}

variable "domain_admin_password" {
  description = "Domain Administrator password"
  type        = string
  sensitive   = true
}

# ===================================
# Scale Configuration
# ===================================

variable "domain_controller_count" {
  description = "Number of domain controllers to deploy"
  type        = number
  default     = 2
}

variable "client_count" {
  description = "Number of Windows client machines to deploy"
  type        = number
  default     = 1
}

# ===================================
# Security Configuration
# ===================================

variable "allowed_rdp_cidrs" {
  description = "CIDR blocks allowed to RDP into instances"
  type        = list(string)
  default     = []
}

variable "allowed_winrm_cidrs" {
  description = "CIDR blocks allowed to WinRM into instances (for Ansible)"
  type        = list(string)
  default     = []
}

# ===================================
# Ansible Configuration
# ===================================

variable "ansible_user" {
  description = "Ansible WinRM username"
  type        = string
  default     = "azureadmin"  # Azure doesn't allow "Administrator"
}

# ===================================
# VM Configuration
# ===================================

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 128
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
