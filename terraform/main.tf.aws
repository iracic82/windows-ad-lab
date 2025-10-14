# ============================================================================
# AWS Windows Active Directory Lab - Modular Configuration
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# ============================================================================
# Data Sources
# ============================================================================

# Get VPC details
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Get subnet details for IP calculation
data "aws_subnet" "selected" {
  count = length(var.subnets)
  id    = var.subnets[count.index]
}

# Get Windows Server 2025 AMI
data "aws_ami" "windows_2025" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }

  filter {
    name   = "platform"
    values = ["windows"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  windows_ami_id = var.windows_ami != "" ? var.windows_ami : data.aws_ami.windows_2025.id

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Calculate private IPs for DCs (starting from .5)
  # Use low IPs to avoid conflicts with existing resources
  dc_private_ips = [
    for idx in range(var.domain_controller_count) :
    cidrhost(data.aws_subnet.selected[idx % length(var.subnets)].cidr_block, 5 + idx)
  ]

  # Calculate private IPs for clients (starting from .8)
  # Start after DCs to avoid IP conflicts
  client_private_ips = [
    for idx in range(var.client_count) :
    cidrhost(data.aws_subnet.selected[idx % length(var.subnets)].cidr_block, 5 + var.domain_controller_count + idx)
  ]
}

# ============================================================================
# Modules
# ============================================================================

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  project_name        = var.project_name
  vpc_id              = var.vpc_id
  allowed_rdp_cidrs   = var.allowed_rdp_cidrs
  allowed_winrm_cidrs = var.allowed_winrm_cidrs
  common_tags         = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  common_tags  = local.common_tags
}

# Domain Controllers
module "domain_controllers" {
  source = "./modules/windows-instance"
  count  = var.domain_controller_count

  project_name      = var.project_name
  name              = "dc${count.index + 1}"
  role              = "domain_controller"
  ami_id            = local.windows_ami_id
  instance_type     = var.dc_instance_type
  subnet_id         = var.subnets[count.index % length(var.subnets)]
  private_ip        = local.dc_private_ips[count.index]
  security_group_id = module.security_groups.dc_sg_id
  iam_profile_name  = module.iam.instance_profile_name
  key_name          = var.key_name
  admin_password    = var.domain_admin_password
  root_volume_size  = var.root_volume_size
  create_eip        = true
  common_tags       = local.common_tags

  depends_on = [
    module.security_groups,
    module.iam
  ]
}

# Domain Clients
module "clients" {
  source = "./modules/windows-instance"
  count  = var.client_count

  project_name      = var.project_name
  name              = "client${count.index + 1}"
  role              = "domain_client"
  ami_id            = local.windows_ami_id
  instance_type     = var.client_instance_type
  subnet_id         = var.subnets[count.index % length(var.subnets)]
  private_ip        = local.client_private_ips[count.index]
  security_group_id = module.security_groups.client_sg_id
  iam_profile_name  = module.iam.instance_profile_name
  key_name          = var.key_name
  admin_password    = var.domain_admin_password
  dc1_ip            = local.dc_private_ips[0]  # First DC IP
  root_volume_size  = var.root_volume_size
  create_eip        = true
  common_tags       = local.common_tags

  depends_on = [
    module.security_groups,
    module.iam
  ]
}

# Ansible Inventory Module
module "ansible_inventory" {
  source = "./modules/ansible-inventory"

  domain_controllers = [
    for idx in range(var.domain_controller_count) : {
      name       = module.domain_controllers[idx].name
      public_ip  = module.domain_controllers[idx].public_ip
      private_ip = module.domain_controllers[idx].private_ip
    }
  ]

  clients = [
    for idx in range(var.client_count) : {
      name       = module.clients[idx].name
      public_ip  = module.clients[idx].public_ip
      private_ip = module.clients[idx].private_ip
    }
  ]

  ansible_user     = var.ansible_user
  ansible_password = var.domain_admin_password
  domain_name      = var.domain_name
  output_path      = "../ansible/inventory/aws_windows.yml"

  depends_on = [
    module.domain_controllers,
    module.clients
  ]
}
