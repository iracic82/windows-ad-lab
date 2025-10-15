# ============================================================================
# Security Groups Module (AWS Only)
# Creates: DC security group, Client security group with all necessary rules
# Supports: Same VPC and Multi-VPC deployments
# ============================================================================

# Get VPC details for CIDR blocks
data "aws_vpc" "dc_vpc" {
  id = var.dc_vpc_id
}

data "aws_vpc" "client_vpc" {
  count = var.use_separate_vpcs ? 1 : 0
  id    = var.client_vpc_id
}

# ============================================================================
# Domain Controllers Security Group
# ============================================================================

resource "aws_security_group" "domain_controllers" {
  name_prefix = "${var.project_name}-dc-"
  description = "Security group for Windows Domain Controllers"
  vpc_id      = var.dc_vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-domain-controllers"
    }
  )
}

# DNS (TCP + UDP) - from both DC and Client VPCs
resource "aws_vpc_security_group_ingress_rule" "dc_dns_tcp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS TCP from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "DNS-TCP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_tcp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "DNS-TCP-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_udp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS UDP from DC VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "DNS-UDP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_udp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS UDP from Client VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "DNS-UDP-Client-VPC" }
}

# LDAP (TCP + UDP) - CRITICAL: UDP 389 required for DC discovery!
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_tcp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP TCP from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "LDAP-TCP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_tcp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "LDAP-TCP-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP from DC VPC - CRITICAL for domain controller discovery"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "LDAP-UDP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP from Client VPC - CRITICAL for domain controller discovery"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "LDAP-UDP-Client-VPC" }
}

# LDAPS
resource "aws_vpc_security_group_ingress_rule" "dc_ldaps_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAPS from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "LDAPS-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldaps_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAPS from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "LDAPS-Client-VPC" }
}

# Global Catalog
resource "aws_vpc_security_group_ingress_rule" "dc_gc_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3268
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "Global-Catalog-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_gc_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 3268
  to_port           = 3268
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "Global-Catalog-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_gc_ssl_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog SSL from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 3269
  to_port           = 3269
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "Global-Catalog-SSL-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_gc_ssl_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Global Catalog SSL from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 3269
  to_port           = 3269
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "Global-Catalog-SSL-Client-VPC" }
}

# Kerberos (TCP + UDP)
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_tcp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos TCP from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "Kerberos-TCP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_tcp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "Kerberos-TCP-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_udp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos UDP from DC VPC"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "Kerberos-UDP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_udp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos UDP from Client VPC"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "Kerberos-UDP-Client-VPC" }
}

# Kerberos Password Change
resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_pwd_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos Password Change from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "Kerberos-Password-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_pwd_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos Password Change from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 464
  to_port           = 464
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "Kerberos-Password-Client-VPC" }
}

# SMB/CIFS
resource "aws_vpc_security_group_ingress_rule" "dc_smb_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "SMB/CIFS from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "SMB-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_smb_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "SMB/CIFS from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "SMB-Client-VPC" }
}

# RPC
resource "aws_vpc_security_group_ingress_rule" "dc_rpc_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "RPC Endpoint Mapper from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "RPC-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_rpc_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "RPC Endpoint Mapper from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 135
  to_port           = 135
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "RPC-Client-VPC" }
}

# Dynamic RPC Ports
resource "aws_vpc_security_group_ingress_rule" "dc_rpc_dynamic_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Dynamic RPC from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "RPC-Dynamic-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_rpc_dynamic_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Dynamic RPC from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 49152
  to_port           = 65535
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "RPC-Dynamic-Client-VPC" }
}

# NetBIOS
resource "aws_vpc_security_group_ingress_rule" "dc_netbios_name_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Name Service from DC VPC"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 137
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "NetBIOS-Name-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_name_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Name Service from Client VPC"
  ip_protocol       = "udp"
  from_port         = 137
  to_port           = 137
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "NetBIOS-Name-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_datagram_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Datagram Service from DC VPC"
  ip_protocol       = "udp"
  from_port         = 138
  to_port           = 138
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "NetBIOS-Datagram-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_datagram_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Datagram Service from Client VPC"
  ip_protocol       = "udp"
  from_port         = 138
  to_port           = 138
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "NetBIOS-Datagram-Client-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_session_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Session Service from DC VPC"
  ip_protocol       = "tcp"
  from_port         = 139
  to_port           = 139
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "NetBIOS-Session-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_netbios_session_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "NetBIOS Session Service from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 139
  to_port           = 139
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "NetBIOS-Session-Client-VPC" }
}

# DHCP Server
resource "aws_vpc_security_group_ingress_rule" "dc_dhcp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DHCP Server from DC VPC"
  ip_protocol       = "udp"
  from_port         = 67
  to_port           = 67
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "DHCP-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_dhcp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DHCP Server from Client VPC"
  ip_protocol       = "udp"
  from_port         = 67
  to_port           = 67
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "DHCP-Client-VPC" }
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
resource "aws_vpc_security_group_ingress_rule" "dc_icmp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "ICMP Echo (Ping) from DC VPC"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "ICMP-Echo-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "dc_icmp_from_client_vpc" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_controllers.id
  description       = "ICMP Echo (Ping) from Client VPC"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "ICMP-Echo-Client-VPC" }
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
  vpc_id      = var.client_vpc_id

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

# ICMP (Ping) from both VPCs
resource "aws_vpc_security_group_ingress_rule" "client_icmp_from_dc_vpc" {
  security_group_id = aws_security_group.domain_clients.id
  description       = "ICMP Echo (Ping) from DC VPC"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "ICMP-Echo-DC-VPC" }
}

resource "aws_vpc_security_group_ingress_rule" "client_icmp_from_client_vpc" {
  security_group_id = aws_security_group.domain_clients.id
  description       = "ICMP Echo (Ping) from Client VPC"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = var.client_vpc_cidr

  tags = { Name = "ICMP-Echo-Client-VPC" }
}

# Allow all traffic from DCs - use SG reference for same VPC, CIDR for separate VPCs
resource "aws_vpc_security_group_ingress_rule" "client_from_dc_sg" {
  count                        = var.use_separate_vpcs ? 0 : 1
  security_group_id            = aws_security_group.domain_clients.id
  description                  = "All traffic from Domain Controllers (same VPC)"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.domain_controllers.id

  tags = { Name = "From-DCs-SG" }
}

resource "aws_vpc_security_group_ingress_rule" "client_from_dc_cidr" {
  count             = var.use_separate_vpcs ? 1 : 0
  security_group_id = aws_security_group.domain_clients.id
  description       = "All traffic from DC VPC (separate VPCs)"
  ip_protocol       = "-1"
  cidr_ipv4         = var.dc_vpc_cidr

  tags = { Name = "From-DCs-CIDR" }
}

# Egress - Allow all
resource "aws_vpc_security_group_egress_rule" "client_egress" {
  security_group_id = aws_security_group.domain_clients.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "Allow-All-Outbound" }
}
