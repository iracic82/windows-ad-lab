# ============================================================================
# Windows Instance Module - Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "name" {
  description = "Instance name (e.g., dc1, dc2, client-1)"
  type        = string
}

variable "role" {
  description = "Instance role (e.g., domain_controller, domain_client)"
  type        = string
  default     = "windows_server"
}

variable "dc1_ip" {
  description = "DC1 IP address (required for clients)"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "Windows AMI ID"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
}

variable "private_ip" {
  description = "Private IP address"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "iam_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "create_eip" {
  description = "Whether to create and associate an Elastic IP"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
