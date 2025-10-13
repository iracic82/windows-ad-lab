# ============================================================================
# Security Groups Module
# Creates: DC security group, Client security group with all necessary rules
# ============================================================================

# Get VPC details
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ============================================================================
# Domain Controllers Security Group
# ============================================================================

resource "aws_security_group" "domain_controllers" {
  name_prefix = "${var.project_name}-dc-"
  description = "Security group for Windows Domain Controllers"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-domain-controllers"
    }
  )
}

# DNS (TCP + UDP)
resource "aws_vpc_security_group_ingress_rule" "dc_dns_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS TCP"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "DNS-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS UDP"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "DNS-UDP" }
}

# LDAP (TCP + UDP) - CRITICAL: UDP 389 required for DC discovery!
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP TCP"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "LDAP-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP - CRITICAL for domain controller discovery"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "LDAP-UDP" }
}

# LDAPS
resource "aws_vpc_security_group_ingress_rule" "dc_ldaps" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAPS"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "LDAPS" }
}

# Global Catalog
resource "aws_vpc_security_group_ingress_rule" "dc_gc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3268
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "Global-Catalog" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_gc_ssl" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog SSL"
  ip_protocol       = "tcp"
  from_port         = 3269
  to_port           = 3269
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "Global-Catalog-SSL" }
}

# Kerberos (TCP + UDP)
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_tcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos TCP"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "Kerberos-TCP" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos UDP"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "Kerberos-UDP" }
}

# Kerberos Password Change
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_pwd" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos Password Change"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "Kerberos-Password" }
}

# SMB/CIFS
resource "aws_vpc_security_group_ingress_rule" "dc_smb" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "SMB/CIFS"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "SMB" }
}

# RPC
resource "aws_vpc_security_group_ingress_rule" "dc_rpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "RPC Endpoint Mapper"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "RPC" }
}

# Dynamic RPC Ports
resource "aws_vpc_security_group_ingress_rule" "dc_rpc_dynamic" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Dynamic RPC"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "RPC-Dynamic" }
}

# NetBIOS
resource "aws_vpc_security_group_ingress_rule" "dc_netbios_name" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Name Service"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 137
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "NetBIOS-Name" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_datagram" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Datagram Service"
  ip_protocol       = "udp"
  from_port         = 138
  to_port           = 138
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "NetBIOS-Datagram" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_session" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Session Service"
  ip_protocol       = "tcp"
  from_port         = 139
  to_port           = 139
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "NetBIOS-Session" }
}

# DHCP Server
resource "aws_vpc_security_group_ingress_rule" "dc_dhcp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DHCP Server"
  ip_protocol       = "udp"
  from_port         = 67
  to_port           = 67
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "DHCP" }
}

# RDP (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "dc_rdp" {
  for_each = toset(var.allowed_rdp_cidrs)

  security_group_id = aws_security_group.domain_controllers.id
  description       = "RDP from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = each.value

  tags = { Name = "RDP-${replace(each.value, "/", "-")}" }
}

# WinRM HTTP (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "dc_winrm_http" {
  for_each = toset(var.allowed_winrm_cidrs)

  security_group_id = aws_security_group.domain_controllers.id
  description       = "WinRM HTTP from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5985
  cidr_ipv4         = each.value

  tags = { Name = "WinRM-HTTP-${replace(each.value, "/", "-")}" }
}

# WinRM HTTPS (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "dc_winrm_https" {
  for_each = toset(var.allowed_winrm_cidrs)

  security_group_id = aws_security_group.domain_controllers.id
  description       = "WinRM HTTPS from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 5986
  to_port           = 5986
  cidr_ipv4         = each.value

  tags = { Name = "WinRM-HTTPS-${replace(each.value, "/", "-")}" }
}

# ICMP (Ping)
resource "aws_vpc_security_group_ingress_rule" "dc_icmp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "ICMP Echo (Ping)"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "ICMP-Echo" }
}

# Egress - Allow all
resource "aws_vpc_security_group_egress_rule" "dc_egress" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "Allow-All-Outbound" }
}

# ============================================================================
# Domain Clients Security Group
# ============================================================================

resource "aws_security_group" "domain_clients" {
  name_prefix = "${var.project_name}-client-"
  description = "Security group for Windows domain clients"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-domain-clients"
    }
  )
}

# RDP (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "client_rdp" {
  for_each = toset(var.allowed_rdp_cidrs)

  security_group_id = aws_security_group.domain_clients.id
  description       = "RDP from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = each.value

  tags = { Name = "RDP-${replace(each.value, "/", "-")}" }
}

# WinRM HTTP (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "client_winrm_http" {
  for_each = toset(var.allowed_winrm_cidrs)

  security_group_id = aws_security_group.domain_clients.id
  description       = "WinRM HTTP from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 5985
  to_port           = 5985
  cidr_ipv4         = each.value

  tags = { Name = "WinRM-HTTP-${replace(each.value, "/", "-")}" }
}

# WinRM HTTPS (from allowed CIDRs only)
resource "aws_vpc_security_group_ingress_rule" "client_winrm_https" {
  for_each = toset(var.allowed_winrm_cidrs)

  security_group_id = aws_security_group.domain_clients.id
  description       = "WinRM HTTPS from allowed CIDR"
  ip_protocol       = "tcp"
  from_port         = 5986
  to_port           = 5986
  cidr_ipv4         = each.value

  tags = { Name = "WinRM-HTTPS-${replace(each.value, "/", "-")}" }
}

# ICMP (Ping) from VPC
resource "aws_vpc_security_group_ingress_rule" "client_icmp" {
  security_group_id = aws_security_group.domain_clients.id
  description       = "ICMP Echo (Ping)"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = { Name = "ICMP-Echo" }
}

# Allow all traffic from DCs
resource "aws_vpc_security_group_ingress_rule" "client_from_dc" {
  security_group_id            = aws_security_group.domain_clients.id
  description                  = "All traffic from Domain Controllers"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.domain_controllers.id

  tags = { Name = "From-DCs" }
}

# Egress - Allow all
resource "aws_vpc_security_group_egress_rule" "client_egress" {
  security_group_id = aws_security_group.domain_clients.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "Allow-All-Outbound" }
}
