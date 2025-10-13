# ===================================
# Security Group - Domain Controllers
# ===================================

resource "aws_security_group" "domain_controllers" {
  name_prefix = "${var.project_name}-dc-"
  description = "Security group for Active Directory Domain Controllers"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-domain-controllers-sg"
      Role = "DomainController"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDP access from allowed CIDRs
resource "aws_vpc_security_group_ingress_rule" "dc_rdp" {
  count = length(var.allowed_rdp_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.domain_controllers.id
  description       = "RDP access"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = var.allowed_rdp_cidrs[0]

  tags = {
    Name = "RDP"
  }
}

# WinRM HTTP access for Ansible
resource "aws_vpc_security_group_ingress_rule" "dc_winrm_http" {
  count = length(var.allowed_winrm_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.domain_controllers.id
  description       = "WinRM HTTP for Ansible"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5985
  cidr_ipv4         = var.allowed_winrm_cidrs[0]

  tags = {
    Name = "WinRM-HTTP"
  }
}

# WinRM HTTPS access for Ansible
resource "aws_vpc_security_group_ingress_rule" "dc_winrm_https" {
  count = length(var.allowed_winrm_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.domain_controllers.id
  description       = "WinRM HTTPS for Ansible"
  ip_protocol       = "tcp"
  from_port         = 5986
  to_port           = 5986
  cidr_ipv4         = var.allowed_winrm_cidrs[0]

  tags = {
    Name = "WinRM-HTTPS"
  }
}

# AD - LDAP
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP TCP"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "LDAP-TCP"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "LDAP-UDP"
  }
}

# AD - LDAPS
resource "aws_vpc_security_group_ingress_rule" "dc_ldaps" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAPS"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "LDAPS"
  }
}

# AD - Global Catalog
resource "aws_vpc_security_group_ingress_rule" "dc_global_catalog" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3269
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "GlobalCatalog"
  }
}

# DNS
resource "aws_vpc_security_group_ingress_rule" "dc_dns_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS TCP"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "DNS-TCP"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS UDP"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "DNS-UDP"
  }
}

# Kerberos
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos TCP"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "Kerberos-TCP"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos UDP"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "Kerberos-UDP"
  }
}

# Kerberos Password Change
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_password" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos Password Change"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "Kerberos-Password"
  }
}

# SMB
resource "aws_vpc_security_group_ingress_rule" "dc_smb" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "SMB/CIFS"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "SMB"
  }
}

# NetBIOS
resource "aws_vpc_security_group_ingress_rule" "dc_netbios_ns" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Name Service"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 137
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "NetBIOS-NS"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_dgm" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Datagram"
  ip_protocol       = "udp"
  from_port         = 138
  to_port           = 138
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "NetBIOS-DGM"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_ssn" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Session"
  ip_protocol       = "tcp"
  from_port         = 139
  to_port           = 139
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "NetBIOS-SSN"
  }
}

# DHCP
resource "aws_vpc_security_group_ingress_rule" "dc_dhcp_server" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DHCP Server"
  ip_protocol       = "udp"
  from_port         = 67
  to_port           = 67
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "DHCP-Server"
  }
}

# AD Replication
resource "aws_vpc_security_group_ingress_rule" "dc_ad_replication" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "AD Replication"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "AD-Replication-RPC"
  }
}

# Dynamic RPC ports for AD replication
resource "aws_vpc_security_group_ingress_rule" "dc_dynamic_rpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Dynamic RPC for AD Replication"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "Dynamic-RPC"
  }
}

# ICMP for diagnostics
resource "aws_vpc_security_group_ingress_rule" "dc_icmp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "ICMP Echo (ping)"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "ICMP"
  }
}

# Egress - allow all
resource "aws_vpc_security_group_egress_rule" "dc_egress_all" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "AllowAll"
  }
}

# ===================================
# Security Group - Windows Clients
# ===================================

resource "aws_security_group" "windows_clients" {
  name_prefix = "${var.project_name}-client-"
  description = "Security group for Windows domain-joined clients"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-windows-clients-sg"
      Role = "DomainClient"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDP access from allowed CIDRs
resource "aws_vpc_security_group_ingress_rule" "client_rdp" {
  count = length(var.allowed_rdp_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.windows_clients.id
  description       = "RDP access"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = var.allowed_rdp_cidrs[0]

  tags = {
    Name = "RDP"
  }
}

# WinRM HTTP access for Ansible
resource "aws_vpc_security_group_ingress_rule" "client_winrm_http" {
  count = length(var.allowed_winrm_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.windows_clients.id
  description       = "WinRM HTTP for Ansible"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5985
  cidr_ipv4         = var.allowed_winrm_cidrs[0]

  tags = {
    Name = "WinRM-HTTP"
  }
}

# WinRM HTTPS access for Ansible
resource "aws_vpc_security_group_ingress_rule" "client_winrm_https" {
  count = length(var.allowed_winrm_cidrs) > 0 ? 1 : 0

  security_group_id = aws_security_group.windows_clients.id
  description       = "WinRM HTTPS for Ansible"
  ip_protocol       = "tcp"
  from_port         = 5986
  to_port           = 5986
  cidr_ipv4         = var.allowed_winrm_cidrs[0]

  tags = {
    Name = "WinRM-HTTPS"
  }
}

# Allow all traffic from DCs
resource "aws_vpc_security_group_ingress_rule" "client_from_dc" {
  security_group_id = aws_security_group.windows_clients.id
  description       = "All traffic from Domain Controllers"
  ip_protocol       = "-1"

  referenced_security_group_id = aws_security_group.domain_controllers.id

  tags = {
    Name = "FromDC"
  }
}

# Allow all traffic within client group
resource "aws_vpc_security_group_ingress_rule" "client_from_client" {
  security_group_id = aws_security_group.windows_clients.id
  description       = "All traffic within client group"
  ip_protocol       = "-1"

  referenced_security_group_id = aws_security_group.windows_clients.id

  tags = {
    Name = "FromClients"
  }
}

# ICMP for diagnostics
resource "aws_vpc_security_group_ingress_rule" "client_icmp" {
  security_group_id = aws_security_group.windows_clients.id
  description       = "ICMP Echo (ping)"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "ICMP"
  }
}

# Egress - allow all
resource "aws_vpc_security_group_egress_rule" "client_egress_all" {
  security_group_id = aws_security_group.windows_clients.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "AllowAll"
  }
}
