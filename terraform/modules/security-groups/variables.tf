# ============================================================================
# Security Groups Module - Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "allowed_rdp_cidrs" {
  description = "List of CIDR blocks allowed to RDP to instances"
  type        = list(string)
}

variable "allowed_winrm_cidrs" {
  description = "List of CIDR blocks allowed to WinRM to instances"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
