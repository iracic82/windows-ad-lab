# ============================================================================
# Azure Networking Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "use_existing" {
  description = "Use existing VNets/subnets (true) or create new (false)"
  type        = bool
  default     = false
}

# --- For CREATING new VNets ---

variable "dc_vnet_cidr" {
  description = "CIDR block for DC VNet (when creating new)"
  type        = string
  default     = ""
}

variable "dc_subnet_cidr" {
  description = "CIDR block for DC subnet (when creating new)"
  type        = string
  default     = ""
}

variable "client_vnet_cidr" {
  description = "CIDR block for Client VNet (when creating new)"
  type        = string
  default     = ""
}

variable "client_subnet_cidr" {
  description = "CIDR block for Client subnet (when creating new)"
  type        = string
  default     = ""
}

# --- For USING existing VNets ---

variable "existing_resource_group_name" {
  description = "Resource group containing existing VNets"
  type        = string
  default     = ""
}

variable "existing_dc_vnet_name" {
  description = "Name of existing DC VNet"
  type        = string
  default     = ""
}

variable "existing_dc_subnet_name" {
  description = "Name of existing DC subnet"
  type        = string
  default     = ""
}

variable "existing_client_vnet_name" {
  description = "Name of existing Client VNet"
  type        = string
  default     = ""
}

variable "existing_client_subnet_name" {
  description = "Name of existing Client subnet"
  type        = string
  default     = ""
}

variable "allowed_rdp_ips" {
  description = "IP addresses allowed to RDP"
  type        = list(string)
  default     = []
}

variable "allowed_winrm_ips" {
  description = "IP addresses allowed for WinRM (Ansible)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
