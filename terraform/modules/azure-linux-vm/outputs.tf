# ============================================================================
# Azure Linux VM Module Outputs
# ============================================================================

output "vm_id" {
  description = "Virtual Machine ID"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Virtual Machine name"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "hostname" {
  description = "VM hostname"
  value       = azurerm_linux_virtual_machine.vm.computer_name
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "public_ip" {
  description = "Public IP address (if created)"
  value       = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : ""
}

output "nic_id" {
  description = "Network interface ID"
  value       = azurerm_network_interface.vm_nic.id
}

output "admin_username" {
  description = "Admin username"
  value       = var.admin_username
}

output "nsg_id" {
  description = "Network Security Group ID"
  value       = var.create_nsg ? azurerm_network_security_group.vm_nsg[0].id : null
}

output "nsg_name" {
  description = "Network Security Group name"
  value       = var.create_nsg ? azurerm_network_security_group.vm_nsg[0].name : null
}
