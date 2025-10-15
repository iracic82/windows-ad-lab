# ============================================================================
# AWS Windows Active Directory Lab - Simplified Variables
# ============================================================================

# ===================================
# AWS Configuration
# ===================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (e.g., 'okta-sso', 'default', or your custom profile)"
  type        = string
  default     = "default"
}

# ===================================
# Project Tags
# ===================================

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "windows-ad-lab"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

# ===================================
# Network Configuration
# ===================================

# -------------------------------------
# VPC Configuration Mode
# -------------------------------------
variable "use_existing_vpcs" {
  description = "Use existing VPCs instead of creating new ones"
  type        = bool
  default     = true  # Backward compatible - default to existing VPCs
}

variable "use_separate_vpcs" {
  description = "Use separate VPCs for DCs and Clients (if false, both use same VPC)"
  type        = bool
  default     = false
}

# -------------------------------------
# Existing VPC Configuration (when use_existing_vpcs = true)
# -------------------------------------
variable "vpc_id" {
  description = "Existing VPC ID for single VPC deployment (when use_separate_vpcs = false)"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "Existing subnet IDs for single VPC deployment (round-robin distribution)"
  type        = list(string)
  default     = []
}

variable "existing_dc_vpc_id" {
  description = "Existing VPC ID for Domain Controllers (when use_separate_vpcs = true)"
  type        = string
  default     = ""
}

variable "existing_dc_subnets" {
  description = "Existing subnet IDs for Domain Controllers in separate VPC mode"
  type        = list(string)
  default     = []
}

variable "existing_client_vpc_id" {
  description = "Existing VPC ID for Clients (when use_separate_vpcs = true, can be same as dc_vpc_id)"
  type        = string
  default     = ""
}

variable "existing_client_subnets" {
  description = "Existing subnet IDs for Clients in separate VPC mode"
  type        = list(string)
  default     = []
}

# -------------------------------------
# New VPC Configuration (when use_existing_vpcs = false)
# -------------------------------------
variable "create_dc_vpc" {
  description = "Create new VPC for Domain Controllers (when use_existing_vpcs = false)"
  type        = bool
  default     = true
}

variable "dc_vpc_cidr" {
  description = "CIDR block for DC VPC (when creating new VPC)"
  type        = string
  default     = "10.10.0.0/16"
}

variable "dc_subnet_cidr" {
  description = "CIDR block for DC subnet (when creating new VPC)"
  type        = string
  default     = "10.10.10.0/24"
}

variable "create_client_vpc" {
  description = "Create new VPC for Clients (when use_existing_vpcs = false and use_separate_vpcs = true)"
  type        = bool
  default     = true
}

variable "client_vpc_cidr" {
  description = "CIDR block for Client VPC (when creating new VPC)"
  type        = string
  default     = "10.11.0.0/16"
}

variable "client_subnet_cidr" {
  description = "CIDR block for Client subnet (when creating new VPC)"
  type        = string
  default     = "10.11.11.0/24"
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
  description = "Domain Administrator password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

# ===================================
# Instance Configuration - SIMPLIFIED!
# ===================================

variable "domain_controller_count" {
  description = "Number of domain controllers to deploy (minimum 1)"
  type        = number
  default     = 2

  validation {
    condition     = var.domain_controller_count >= 1
    error_message = "At least 1 domain controller is required."
  }
}

variable "client_count" {
  description = "Number of Windows client machines to deploy"
  type        = number
  default     = 1

  validation {
    condition     = var.client_count >= 0
    error_message = "Client count must be 0 or greater."
  }
}

variable "dc_instance_type" {
  description = "Instance type for Domain Controllers"
  type        = string
  default     = "t3.large"
}

variable "client_instance_type" {
  description = "Instance type for client machines"
  type        = string
  default     = "t3.medium"
}

variable "windows_ami" {
  description = "AMI ID for Windows Server (leave empty to auto-detect latest Windows Server 2025)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 Key Pair name for RDP access"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
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
# IP Address Customization
# ===================================

variable "dc_private_ips" {
  description = "List of private IP addresses for Domain Controllers (optional - will auto-calculate if not provided)"
  type        = list(string)
  default     = []
}

variable "client_private_ips" {
  description = "List of private IP addresses for Clients (optional - will auto-calculate if not provided)"
  type        = list(string)
  default     = []
}

variable "dc_ip_start_offset" {
  description = "Starting IP offset for auto-calculated DC IPs (e.g., 5 means .5, .6, .7...)"
  type        = number
  default     = 5
}

variable "client_ip_start_offset" {
  description = "Starting IP offset for auto-calculated Client IPs (e.g., 5 means .5, .6, .7... or after DCs if same VPC)"
  type        = number
  default     = 5
}

# ===================================
# Ansible Configuration
# ===================================

variable "ansible_user" {
  description = "Ansible WinRM username"
  type        = string
  default     = "Administrator"
}
