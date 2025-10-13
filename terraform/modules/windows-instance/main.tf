# ============================================================================
# Windows Instance Module
# Creates: ENI + EC2 Instance + EIP
# ============================================================================

# Create Elastic Network Interface
resource "aws_network_interface" "eni" {
  subnet_id       = var.subnet_id
  private_ips     = [var.private_ip]
  security_groups = [var.security_group_id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.name}-eni"
    }
  )
}

# Create EC2 Instance
resource "aws_instance" "instance" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = var.iam_profile_name

  network_interface {
    network_interface_id = aws_network_interface.eni.id
    device_index         = 0
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile(
    var.role == "domain_controller" ? "${path.root}/templates/dc_userdata.tpl" : "${path.root}/templates/client_userdata.tpl",
    var.role == "domain_controller" ? {
      computer_name        = upper(var.name)
      domain_admin_password = var.admin_password
    } : {
      computer_name        = upper(var.name)
      domain_admin_password = var.admin_password
      dc1_ip               = var.dc1_ip
    }
  ))

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${upper(var.name)}"
      Role = var.role
    }
  )

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Create Elastic IP (optional)
resource "aws_eip" "eip" {
  count  = var.create_eip ? 1 : 0
  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.name}-eip"
    }
  )
}

# Associate EIP with ENI
resource "aws_eip_association" "eip_assoc" {
  count                = var.create_eip ? 1 : 0
  network_interface_id = aws_network_interface.eni.id
  allocation_id        = aws_eip.eip[0].id
}
