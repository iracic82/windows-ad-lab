# ============================================================================
# AWS VPC Module - Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "vpc_name" {
  description = "Name suffix for the VPC (e.g., 'dc' or 'client')"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
