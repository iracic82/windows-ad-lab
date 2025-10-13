# ===================================
# Elastic IPs for Remote Access
# ===================================

# Elastic IP for DC1
resource "aws_eip" "dc1" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-dc1-eip"
      Instance = "DC1"
    }
  )
}

resource "aws_eip_association" "dc1" {
  network_interface_id = aws_network_interface.dc1_eni.id
  allocation_id        = aws_eip.dc1.id
  private_ip_address   = var.dc1_private_ip
}

# Elastic IP for DC2
resource "aws_eip" "dc2" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-dc2-eip"
      Instance = "DC2"
    }
  )
}

resource "aws_eip_association" "dc2" {
  network_interface_id = aws_network_interface.dc2_eni.id
  allocation_id        = aws_eip.dc2.id
  private_ip_address   = var.dc2_private_ip
}

# Elastic IPs for Clients
resource "aws_eip" "clients" {
  count  = var.client_count
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.client_name_prefix}-${count.index + 1}-eip"
      Instance = "${var.client_name_prefix}-${count.index + 1}"
    }
  )
}

resource "aws_eip_association" "clients" {
  count                = var.client_count
  network_interface_id = aws_network_interface.client_eni[count.index].id
  allocation_id        = aws_eip.clients[count.index].id
  private_ip_address   = local.client_ips_map[count.index]
}
