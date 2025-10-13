# ===================================
# Ansible Inventory Generation
# ===================================

locals {
  ansible_inventory_content = templatefile("${path.module}/templates/ansible_inventory.tpl", {
    dc1_ip               = aws_instance.dc1.private_ip
    dc1_public_ip        = aws_eip.dc1.public_ip
    dc2_ip               = aws_instance.dc2.private_ip
    dc2_public_ip        = aws_eip.dc2.public_ip
    clients              = [
      for idx, instance in aws_instance.clients : {
        name       = "client${idx + 1}"
        private_ip = instance.private_ip
        public_ip  = aws_eip.clients[idx].public_ip
      }
    ]
    ansible_user         = var.ansible_user
    ansible_password     = var.domain_admin_password
    domain_name          = var.domain_name
    domain_netbios       = var.domain_netbios
  })
}

resource "local_file" "ansible_inventory" {
  count = var.generate_ansible_inventory ? 1 : 0

  content  = local.ansible_inventory_content
  filename = var.ansible_inventory_path

  file_permission = "0644"
}
