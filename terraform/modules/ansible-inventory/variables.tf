# ============================================================================
# Ansible Inventory Module - Variables
# ============================================================================

variable "domain_controllers" {
  description = "List of domain controller instances with name, public_ip, and private_ip"
  type = list(object({
    name       = string
    public_ip  = string
    private_ip = string
  }))
}

variable "clients" {
  description = "List of client instances with name, public_ip, and private_ip"
  type = list(object({
    name       = string
    public_ip  = string
    private_ip = string
  }))
  default = []
}

variable "ansible_user" {
  description = "Ansible connection username"
  type        = string
  default     = "Administrator"
}

variable "ansible_password" {
  description = "Ansible connection password"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
}

variable "output_path" {
  description = "Path where inventory file will be created"
  type        = string
}
