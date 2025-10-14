# ============================================================================
# Azure Windows VM Module Outputs
# ============================================================================

output "vm_id" {
  description = "VM ID"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_name" {
  description = "VM name"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "name" {
  description = "Name (dc1, client1, etc.)"
  value       = var.name
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "public_ip" {
  description = "Public IP address"
  value       = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : ""
}
