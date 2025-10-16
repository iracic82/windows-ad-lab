# ============================================================================
# Azure Windows VM Module Variables
# ============================================================================

variable "vm_name_prefix" {
  description = "Short prefix for VM names (e.g., 'winadlab')"
  type        = string
}

variable "name" {
  description = "Name of the VM (e.g., dc1, client1)"
  type        = string
}

variable "role" {
  description = "Role of the VM (domain_controller or domain_client)"
  type        = string
  validation {
    condition     = contains(["domain_controller", "domain_client"], var.role)
    error_message = "Role must be either 'domain_controller' or 'domain_client'."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "windows_sku" {
  description = "Windows Server SKU"
  type        = string
  default     = "2022-datacenter-g2"
}

variable "subnet_id" {
  description = "Subnet ID for the VM"
  type        = string
}

variable "private_ip" {
  description = "Static private IP address"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "dc1_ip" {
  description = "DC1 IP address (for clients only)"
  type        = string
  default     = ""
}

variable "os_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "create_public_ip" {
  description = "Whether to create a public IP"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
