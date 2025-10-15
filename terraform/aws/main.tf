# ============================================================================
# AWS Windows Active Directory Lab - Modular Configuration with Multi-VPC Support
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

# Get availability zones for VPC creation
data "aws_availability_zones" "available" {
  state = "available"
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

# Get existing VPC details
data "aws_vpc" "selected" {
  count = var.use_existing_vpcs && !var.use_separate_vpcs ? 1 : 0
  id    = var.vpc_id
}

data "aws_vpc" "dc_vpc" {
  count = (var.use_existing_vpcs && var.use_separate_vpcs) || (!var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc) ? 1 : 0
  id    = var.existing_dc_vpc_id
}

data "aws_vpc" "client_vpc" {
  count = (var.use_existing_vpcs && var.use_separate_vpcs) || (!var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc) ? 1 : 0
  id    = var.existing_client_vpc_id
}

# Get existing subnet details for IP calculation
data "aws_subnet" "selected" {
  count = var.use_existing_vpcs && !var.use_separate_vpcs ? length(var.subnets) : 0
  id    = var.subnets[count.index]
}

data "aws_subnet" "dc_subnets" {
  count = (var.use_existing_vpcs && var.use_separate_vpcs) || (!var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc) ? length(var.existing_dc_subnets) : 0
  id    = var.existing_dc_subnets[count.index]
}

data "aws_subnet" "client_subnets" {
  count = (var.use_existing_vpcs && var.use_separate_vpcs) || (!var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc) ? length(var.existing_client_subnets) : 0
  id    = var.existing_client_subnets[count.index]
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

  # Determine actual VPC IDs and CIDRs based on configuration mode
  dc_vpc_id = (
    !var.use_existing_vpcs && var.create_dc_vpc ? module.dc_vpc[0].vpc_id :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc ? var.existing_dc_vpc_id :
    var.use_existing_vpcs && var.use_separate_vpcs ? var.existing_dc_vpc_id :
    var.use_existing_vpcs && !var.use_separate_vpcs ? var.vpc_id :
    ""
  )

  dc_vpc_cidr = (
    !var.use_existing_vpcs && var.create_dc_vpc ? module.dc_vpc[0].vpc_cidr :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc ? data.aws_vpc.dc_vpc[0].cidr_block :
    var.use_existing_vpcs && var.use_separate_vpcs ? data.aws_vpc.dc_vpc[0].cidr_block :
    var.use_existing_vpcs && !var.use_separate_vpcs ? data.aws_vpc.selected[0].cidr_block :
    ""
  )

  client_vpc_id = (
    !var.use_existing_vpcs && var.use_separate_vpcs && var.create_client_vpc ? module.client_vpc[0].vpc_id :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc ? var.existing_client_vpc_id :
    var.use_existing_vpcs && var.use_separate_vpcs ? var.existing_client_vpc_id :
    local.dc_vpc_id  # Same VPC mode
  )

  client_vpc_cidr = (
    !var.use_existing_vpcs && var.use_separate_vpcs && var.create_client_vpc ? module.client_vpc[0].vpc_cidr :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc ? data.aws_vpc.client_vpc[0].cidr_block :
    var.use_existing_vpcs && var.use_separate_vpcs ? data.aws_vpc.client_vpc[0].cidr_block :
    local.dc_vpc_cidr  # Same VPC mode
  )

  # Determine actual subnet IDs
  dc_subnets = (
    !var.use_existing_vpcs && var.create_dc_vpc ? [module.dc_vpc[0].subnet_id] :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc ? var.existing_dc_subnets :
    var.use_existing_vpcs && var.use_separate_vpcs ? var.existing_dc_subnets :
    var.use_existing_vpcs && !var.use_separate_vpcs ? var.subnets :
    []
  )

  client_subnets = (
    !var.use_existing_vpcs && var.use_separate_vpcs && var.create_client_vpc ? [module.client_vpc[0].subnet_id] :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc ? var.existing_client_subnets :
    var.use_existing_vpcs && var.use_separate_vpcs ? var.existing_client_subnets :
    local.dc_subnets  # Same VPC mode
  )

  # Determine subnet CIDR blocks for IP calculation
  dc_subnet_cidrs = (
    !var.use_existing_vpcs && var.create_dc_vpc ? [module.dc_vpc[0].subnet_cidr] :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_dc_vpc ? [for s in data.aws_subnet.dc_subnets : s.cidr_block] :
    var.use_existing_vpcs && var.use_separate_vpcs ? [for s in data.aws_subnet.dc_subnets : s.cidr_block] :
    var.use_existing_vpcs && !var.use_separate_vpcs ? [for s in data.aws_subnet.selected : s.cidr_block] :
    []
  )

  client_subnet_cidrs = (
    !var.use_existing_vpcs && var.use_separate_vpcs && var.create_client_vpc ? [module.client_vpc[0].subnet_cidr] :
    !var.use_existing_vpcs && var.use_separate_vpcs && !var.create_client_vpc ? [for s in data.aws_subnet.client_subnets : s.cidr_block] :
    var.use_existing_vpcs && var.use_separate_vpcs ? [for s in data.aws_subnet.client_subnets : s.cidr_block] :
    local.dc_subnet_cidrs  # Same VPC mode
  )

  # Check if VPC peering is needed - use variable-based logic instead of resource attributes
  needs_peering = var.use_separate_vpcs

  # Calculate private IPs for DCs - use custom IPs if provided, otherwise auto-calculate
  dc_private_ips = length(var.dc_private_ips) > 0 ? var.dc_private_ips : [
    for idx in range(var.domain_controller_count) :
    cidrhost(local.dc_subnet_cidrs[idx % length(local.dc_subnet_cidrs)], var.dc_ip_start_offset + idx)
  ]

  # Calculate private IPs for clients - use custom IPs if provided, otherwise auto-calculate
  client_private_ips = length(var.client_private_ips) > 0 ? var.client_private_ips : [
    for idx in range(var.client_count) :
    cidrhost(
      local.client_subnet_cidrs[idx % length(local.client_subnet_cidrs)],
      var.use_separate_vpcs ? (var.client_ip_start_offset + idx) : (var.dc_ip_start_offset + var.domain_controller_count + idx)
    )
  ]
}

# ============================================================================
# VPC Creation (when use_existing_vpcs = false)
# ============================================================================

# Create DC VPC
module "dc_vpc" {
  count  = !var.use_existing_vpcs && var.create_dc_vpc ? 1 : 0
  source = "./modules/aws-vpc"

  vpc_cidr          = var.dc_vpc_cidr
  subnet_cidr       = var.dc_subnet_cidr
  vpc_name          = "dc"
  project_name      = var.project_name
  availability_zone = data.aws_availability_zones.available.names[0]
  common_tags       = local.common_tags
}

# Create Client VPC (only when use_separate_vpcs = true)
module "client_vpc" {
  count  = !var.use_existing_vpcs && var.use_separate_vpcs && var.create_client_vpc ? 1 : 0
  source = "./modules/aws-vpc"

  vpc_cidr          = var.client_vpc_cidr
  subnet_cidr       = var.client_subnet_cidr
  vpc_name          = "client"
  project_name      = var.project_name
  availability_zone = data.aws_availability_zones.available.names[0]
  common_tags       = local.common_tags
}

# ============================================================================
# VPC Peering (when using separate VPCs)
# ============================================================================

module "vpc_peering" {
  count  = local.needs_peering ? 1 : 0
  source = "./modules/vpc-peering"

  dc_vpc_id        = local.dc_vpc_id
  client_vpc_id    = local.client_vpc_id
  dc_vpc_cidr      = local.dc_vpc_cidr
  client_vpc_cidr  = local.client_vpc_cidr
  project_name     = var.project_name
  common_tags      = local.common_tags

  depends_on = [
    module.dc_vpc,
    module.client_vpc
  ]
}

# ============================================================================
# Modules
# ============================================================================

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  project_name        = var.project_name
  dc_vpc_id           = local.dc_vpc_id
  client_vpc_id       = local.client_vpc_id
  dc_vpc_cidr         = local.dc_vpc_cidr
  client_vpc_cidr     = local.client_vpc_cidr
  use_separate_vpcs   = var.use_separate_vpcs
  allowed_rdp_cidrs   = var.allowed_rdp_cidrs
  allowed_winrm_cidrs = var.allowed_winrm_cidrs
  common_tags         = local.common_tags

  depends_on = [
    module.dc_vpc,
    module.client_vpc
  ]
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
  subnet_id         = local.dc_subnets[count.index % length(local.dc_subnets)]
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
    module.iam,
    module.vpc_peering
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
  subnet_id         = local.client_subnets[count.index % length(local.client_subnets)]
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
    module.iam,
    module.vpc_peering
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

  ansible_user      = var.ansible_user
  ansible_password  = var.domain_admin_password
  domain_name       = var.domain_name
  domain_netbios    = "CORP"
  domain_admin_user = "CORP\\${var.ansible_user}"
  output_path       = "../ansible/inventory/aws_windows.yml"

  depends_on = [
    module.domain_controllers,
    module.clients
  ]
}
