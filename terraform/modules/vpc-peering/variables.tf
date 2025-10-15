# ============================================================================
# VPC Peering Module - Variables
# ============================================================================

variable "dc_vpc_id" {
  description = "VPC ID for Domain Controllers"
  type        = string
}

variable "client_vpc_id" {
  description = "VPC ID for Clients"
  type        = string
}

variable "dc_vpc_cidr" {
  description = "CIDR block for DC VPC"
  type        = string
}

variable "client_vpc_cidr" {
  description = "CIDR block for Client VPC"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
