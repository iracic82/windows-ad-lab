# ============================================================================
# Azure Windows Active Directory Lab - Outputs
# ============================================================================

output "azure_resource_group_name" {
  description = "Azure Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "azure_dc_vnet_name" {
  description = "DC VNet name"
  value       = module.azure_networking.dc_vnet_name
}

output "azure_client_vnet_name" {
  description = "Client VNet name"
  value       = module.azure_networking.client_vnet_name
}

output "azure_domain_controllers" {
  description = "Domain Controller information"
  value = {
    for idx, dc in module.azure_domain_controllers : dc.name => {
      name       = dc.name
      private_ip = dc.private_ip
      public_ip  = dc.public_ip
    }
  }
}

output "azure_clients" {
  description = "Client information"
  value = {
    for idx, client in module.azure_clients : client.name => {
      name       = client.name
      private_ip = client.private_ip
      public_ip  = client.public_ip
    }
  }
}

output "azure_rdp_connection_info" {
  description = "RDP connection information"
  value = <<-EOT

  ============================================
  Azure AD Lab - RDP Connection Information
  ============================================

  Domain Controllers:
  %{for idx, dc in module.azure_domain_controllers~}
  - ${dc.name}: ${dc.public_ip} (Private: ${dc.private_ip})
  %{endfor~}

  Clients:
  %{for idx, client in module.azure_clients~}
  - ${client.name}: ${client.public_ip} (Private: ${client.private_ip})
  %{endfor~}

  Credentials:
  - Username: Administrator
  - Password: ${var.domain_admin_password}
  - Domain: ${var.domain_name}

  ============================================
  EOT
  sensitive = true
}
