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
# Network Configuration - SIMPLIFIED!
# ===================================

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for instance deployment (round-robin distribution)"
  type        = list(string)

  validation {
    condition     = length(var.subnets) >= 1
    error_message = "At least one subnet must be provided."
  }
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
# Ansible Configuration
# ===================================

variable "ansible_user" {
  description = "Ansible WinRM username"
  type        = string
  default     = "Administrator"
}
