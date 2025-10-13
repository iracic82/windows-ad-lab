# ============================================================================
# Ansible Inventory Module - Outputs
# ============================================================================

output "inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "inventory_content" {
  description = "Content of the generated Ansible inventory"
  value       = local_file.ansible_inventory.content
  sensitive   = true
}
