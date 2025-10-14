# ============================================================================
# Ansible Inventory Module
# Creates: Ansible inventory file from instance information
# ============================================================================

locals {
  # Build domain controllers host entries
  dc_hosts = {
    for idx, dc in var.domain_controllers : dc.name => {
      ansible_host = dc.public_ip
      private_ip   = dc.private_ip
    }
  }

  # Build clients host entries
  client_hosts = {
    for idx, client in var.clients : client.name => {
      ansible_host = client.public_ip
      private_ip   = client.private_ip
    }
  }

  # Get first DC's private IP for dc1_ip variable
  dc1_ip = length(var.domain_controllers) > 0 ? var.domain_controllers[0].private_ip : ""

  # Get second DC's private IP for dc2_ip variable (if exists)
  dc2_ip = length(var.domain_controllers) > 1 ? var.domain_controllers[1].private_ip : ""
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    ansible_user      = var.ansible_user
    ansible_password  = var.ansible_password
    domain_name       = var.domain_name
    domain_netbios    = var.domain_netbios
    domain_admin_user = var.domain_admin_user
    dc1_ip            = local.dc1_ip
    dc2_ip            = local.dc2_ip
    dc_hosts          = local.dc_hosts
    client_hosts      = local.client_hosts
  })

  filename        = var.output_path
  file_permission = "0600"
}
