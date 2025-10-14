# ============================================================================
# Azure Networking Module Outputs
# ============================================================================

output "dc_vnet_id" {
  description = "DC VNet ID (created or existing)"
  value       = local.dc_vnet_id
}

output "dc_vnet_name" {
  description = "DC VNet name (created or existing)"
  value       = local.dc_vnet_name
}

output "dc_subnet_id" {
  description = "DC Subnet ID (created or existing)"
  value       = local.dc_subnet_id
}

output "client_vnet_id" {
  description = "Client VNet ID (created or existing)"
  value       = local.client_vnet_id
}

output "client_vnet_name" {
  description = "Client VNet name (created or existing)"
  value       = local.client_vnet_name
}

output "client_subnet_id" {
  description = "Client Subnet ID (created or existing)"
  value       = local.client_subnet_id
}

output "dc_nsg_id" {
  description = "DC Network Security Group ID"
  value       = azurerm_network_security_group.dc_nsg.id
}

output "client_nsg_id" {
  description = "Client Network Security Group ID"
  value       = azurerm_network_security_group.client_nsg.id
}
