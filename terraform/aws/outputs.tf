# ============================================================================
# AWS Windows Active Directory Lab - Outputs
# ============================================================================

# ===================================
# VPC Information
# ===================================

output "dc_vpc_id" {
  description = "DC VPC ID"
  value       = local.dc_vpc_id
}

output "dc_vpc_cidr" {
  description = "DC VPC CIDR block"
  value       = local.dc_vpc_cidr
}

output "client_vpc_id" {
  description = "Client VPC ID"
  value       = local.client_vpc_id
}

output "client_vpc_cidr" {
  description = "Client VPC CIDR block"
  value       = local.client_vpc_cidr
}

output "vpc_peering_id" {
  description = "VPC Peering connection ID (if separate VPCs)"
  value       = local.needs_peering ? module.vpc_peering[0].peering_connection_id : null
}

output "vpc_peering_status" {
  description = "VPC Peering connection status (if separate VPCs)"
  value       = local.needs_peering ? module.vpc_peering[0].peering_status : null
}

output "network_mode" {
  description = "Network deployment mode"
  value = var.use_separate_vpcs ? (
    local.dc_vpc_id == local.client_vpc_id ? "Separate VPCs (same VPC used)" : "Separate VPCs with peering"
  ) : "Single VPC"
}

# ===================================
# Domain Controllers
# ===================================

output "dc_instance_ids" {
  description = "Domain Controller instance IDs"
  value       = [for dc in module.domain_controllers : dc.instance_id]
}

output "dc_private_ips" {
  description = "Domain Controller private IPs"
  value       = [for dc in module.domain_controllers : dc.private_ip]
}

output "dc_public_ips" {
  description = "Domain Controller public IPs (EIPs)"
  value       = [for dc in module.domain_controllers : dc.public_ip]
}

output "dc_details" {
  description = "Domain Controller details (name, IPs)"
  value = {
    for idx, dc in module.domain_controllers : dc.name => {
      instance_id = dc.instance_id
      private_ip  = dc.private_ip
      public_ip   = dc.public_ip
    }
  }
}

# ===================================
# Clients
# ===================================

output "client_instance_ids" {
  description = "Client instance IDs"
  value       = [for client in module.clients : client.instance_id]
}

output "client_private_ips" {
  description = "Client private IPs"
  value       = [for client in module.clients : client.private_ip]
}

output "client_public_ips" {
  description = "Client public IPs (EIPs)"
  value       = [for client in module.clients : client.public_ip]
}

output "client_details" {
  description = "Client details (name, IPs)"
  value = {
    for idx, client in module.clients : client.name => {
      instance_id = client.instance_id
      private_ip  = client.private_ip
      public_ip   = client.public_ip
    }
  }
}

# ===================================
# Security Groups
# ===================================

output "dc_security_group_id" {
  description = "Domain Controllers security group ID"
  value       = module.security_groups.dc_sg_id
}

output "client_security_group_id" {
  description = "Clients security group ID"
  value       = module.security_groups.client_sg_id
}

# ===================================
# Ansible
# ===================================

output "ansible_inventory_path" {
  description = "Path to Ansible inventory file"
  value       = module.ansible_inventory.inventory_path
}

# ===================================
# RDP Connection Info
# ===================================

output "rdp_connection_info" {
  description = "RDP connection information for all instances"
  value = merge(
    {
      for idx, dc in module.domain_controllers : dc.name => {
        public_ip = dc.public_ip
        username  = "Administrator"
        domain    = var.domain_name
        rdp_url   = "rdp://full%20address=s:${dc.public_ip}:3389"
      }
    },
    {
      for idx, client in module.clients : client.name => {
        public_ip = client.public_ip
        username  = "Administrator"
        domain    = var.domain_name
        rdp_url   = "rdp://full%20address=s:${client.public_ip}:3389"
      }
    }
  )
}

# ===================================
# Quick Start Info
# ===================================

output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT

  ========================================
  Deployment Complete!
  ========================================

  Network Mode: ${var.use_separate_vpcs ? "Separate VPCs" : "Single VPC"}
  ${var.use_separate_vpcs ? "VPC Peering: ${local.needs_peering ? "Enabled" : "Not needed (same VPC)"}" : ""}

  Domain: ${var.domain_name}
  Domain Controllers: ${var.domain_controller_count} (VPC: ${local.dc_vpc_id})
  Clients: ${var.client_count} (VPC: ${local.client_vpc_id})

  Domain Controller IPs:
  ${join("\n  ", [for dc in module.domain_controllers : "${dc.name}: ${dc.public_ip} (private: ${dc.private_ip})"])}

  Client IPs:
  ${var.client_count > 0 ? join("\n  ", [for client in module.clients : "${client.name}: ${client.public_ip} (private: ${client.private_ip})"]) : "None"}

  Next Steps:
  1. Wait 3 minutes for instances to boot: sleep 180
  2. Test connectivity: cd ../ansible && ansible all -i inventory/aws_windows.yml -m win_ping
  3. Run Ansible playbook: ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml

  ========================================
  EOT
}
