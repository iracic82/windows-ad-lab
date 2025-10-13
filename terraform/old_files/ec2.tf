# ===================================
# IAM Role for Systems Manager (SSM)
# ===================================

resource "aws_iam_role" "windows_ssm_role" {
  name_prefix = "${var.project_name}-windows-ssm-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-windows-ssm-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "windows_ssm_policy" {
  role       = aws_iam_role.windows_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "windows_ssm_profile" {
  name_prefix = "${var.project_name}-windows-ssm-"
  role        = aws_iam_role.windows_ssm_role.name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-windows-ssm-profile"
    }
  )
}

# ===================================
# Network Interfaces (ENI)
# ===================================

resource "aws_network_interface" "dc1_eni" {
  subnet_id       = var.subnet_dc1
  private_ips     = [var.dc1_private_ip]
  security_groups = [aws_security_group.domain_controllers.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-dc1-eni"
    }
  )
}

resource "aws_network_interface" "dc2_eni" {
  subnet_id       = var.subnet_dc2
  private_ips     = [var.dc2_private_ip]
  security_groups = [aws_security_group.domain_controllers.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-dc2-eni"
    }
  )
}

resource "aws_network_interface" "client_eni" {
  count = var.client_count

  subnet_id       = local.client_subnet_map[count.index]
  private_ips     = local.client_ips_map[count.index] != null ? [local.client_ips_map[count.index]] : null
  security_groups = [aws_security_group.windows_clients.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-client${count.index + 1}-eni"
    }
  )
}

# ===================================
# Domain Controller 1 (DC1)
# ===================================

resource "aws_instance" "dc1" {
  ami                  = local.windows_ami_id
  instance_type        = var.dc_instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.windows_ssm_profile.name

  network_interface {
    network_interface_id = aws_network_interface.dc1_eni.id
    device_index         = 0
  }

  user_data = base64encode(templatefile("${path.module}/templates/dc_userdata.tpl", {
    computer_name         = "DC1"
    domain_admin_password = var.domain_admin_password
  }))

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-dc1-root"
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-dc1"
      Role        = "DomainController"
      DCNumber    = "1"
      AnsibleRole = "windows"
      AnsibleHost = "dc1"
    }
  )
}

# ===================================
# Domain Controller 2 (DC2)
# ===================================

resource "aws_instance" "dc2" {
  ami                  = local.windows_ami_id
  instance_type        = var.dc_instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.windows_ssm_profile.name

  network_interface {
    network_interface_id = aws_network_interface.dc2_eni.id
    device_index         = 0
  }

  user_data = base64encode(templatefile("${path.module}/templates/dc_userdata.tpl", {
    computer_name         = "DC2"
    domain_admin_password = var.domain_admin_password
  }))

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-dc2-root"
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-dc2"
      Role        = "DomainController"
      DCNumber    = "2"
      AnsibleRole = "windows"
      AnsibleHost = "dc2"
    }
  )

  depends_on = [aws_instance.dc1]
}

# ===================================
# Windows Client Machines
# ===================================

resource "aws_instance" "clients" {
  count = var.client_count

  ami                  = local.windows_ami_id
  instance_type        = var.client_instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.windows_ssm_profile.name

  network_interface {
    network_interface_id = aws_network_interface.client_eni[count.index].id
    device_index         = 0
  }

  user_data = base64encode(templatefile("${path.module}/templates/client_userdata.tpl", {
    computer_name         = "${var.client_name_prefix}-${count.index + 1}"
    domain_admin_password = var.domain_admin_password
    dc1_ip                = var.dc1_private_ip
  }))

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-${var.client_name_prefix}-${count.index + 1}-root"
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name         = "${var.project_name}-${var.client_name_prefix}-${count.index + 1}"
      Role         = "DomainClient"
      ClientNumber = "${count.index + 1}"
      AnsibleRole  = "windows_clients"
      AnsibleHost  = "client${count.index + 1}"
    }
  )

  depends_on = [aws_instance.dc1, aws_instance.dc2]
}
