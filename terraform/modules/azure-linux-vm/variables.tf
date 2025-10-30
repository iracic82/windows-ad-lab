# ============================================================================
# Azure Linux VM Module Variables
# ============================================================================

variable "name" {
  description = "Name of the VM (e.g., bastion-host)"
  type        = string
}

variable "hostname" {
  description = "Hostname for the VM (used as computer_name)"
  type        = string
  default     = ""
}

variable "role" {
  description = "Role of the VM (e.g., bastion, workstation, etc.)"
  type        = string
  default     = "linux-vm"
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
  default     = "Standard_B2s"
}

variable "subnet_id" {
  description = "Subnet ID for the VM"
  type        = string
}

variable "private_ip" {
  description = "Static private IP address (leave empty for dynamic)"
  type        = string
  default     = ""
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password (used if SSH key not provided)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for authentication (preferred method)"
  type        = string
  default     = ""
}

variable "os_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "os_disk_type" {
  description = "OS disk storage account type"
  type        = string
  default     = "Premium_LRS"
}

variable "create_public_ip" {
  description = "Whether to create a public IP"
  type        = bool
  default     = true
}

variable "create_nsg" {
  description = "Whether to create a Network Security Group"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the VM"
  type        = list(string)
  default     = []
}

# Image configuration
variable "image_publisher" {
  description = "VM image publisher"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "VM image offer"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "VM image SKU"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "VM image version"
  type        = string
  default     = "latest"
}

# Cloud-init
variable "cloud_init_data" {
  description = "Cloud-init configuration data (will be base64 encoded automatically)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
