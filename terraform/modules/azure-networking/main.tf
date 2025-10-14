# ============================================================================
# Azure Networking Module
# Supports: Creating NEW VNets OR using EXISTING VNets
# ============================================================================

# ============================================================================
# Data Sources - For Existing VNets
# ============================================================================

data "azurerm_virtual_network" "existing_dc_vnet" {
  count               = var.use_existing ? 1 : 0
  name                = var.existing_dc_vnet_name
  resource_group_name = var.existing_resource_group_name
}

data "azurerm_subnet" "existing_dc_subnet" {
  count                = var.use_existing ? 1 : 0
  name                 = var.existing_dc_subnet_name
  virtual_network_name = var.existing_dc_vnet_name
  resource_group_name  = var.existing_resource_group_name
}

data "azurerm_virtual_network" "existing_client_vnet" {
  count               = var.use_existing ? 1 : 0
  name                = var.existing_client_vnet_name
  resource_group_name = var.existing_resource_group_name
}

data "azurerm_subnet" "existing_client_subnet" {
  count                = var.use_existing ? 1 : 0
  name                 = var.existing_client_subnet_name
  virtual_network_name = var.existing_client_vnet_name
  resource_group_name  = var.existing_resource_group_name
}

# ============================================================================
# Create NEW VNets (when use_existing = false)
# ============================================================================

resource "azurerm_virtual_network" "dc_vnet" {
  count               = var.use_existing ? 0 : 1
  name                = "${var.project_name}-dc-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.dc_vnet_cidr]

  tags = var.common_tags
}

resource "azurerm_subnet" "dc_subnet" {
  count                = var.use_existing ? 0 : 1
  name                 = "${var.project_name}-dc-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dc_vnet[0].name
  address_prefixes     = [var.dc_subnet_cidr]
}

resource "azurerm_virtual_network" "client_vnet" {
  count               = var.use_existing ? 0 : 1
  name                = "${var.project_name}-client-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.client_vnet_cidr]

  tags = var.common_tags
}

resource "azurerm_subnet" "client_subnet" {
  count                = var.use_existing ? 0 : 1
  name                 = "${var.project_name}-client-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.client_vnet[0].name
  address_prefixes     = [var.client_subnet_cidr]
}

# ============================================================================
# Locals - Select between created or existing resources
# ============================================================================

locals {
  dc_vnet_id   = var.use_existing ? data.azurerm_virtual_network.existing_dc_vnet[0].id : azurerm_virtual_network.dc_vnet[0].id
  dc_vnet_name = var.use_existing ? data.azurerm_virtual_network.existing_dc_vnet[0].name : azurerm_virtual_network.dc_vnet[0].name
  dc_subnet_id = var.use_existing ? data.azurerm_subnet.existing_dc_subnet[0].id : azurerm_subnet.dc_subnet[0].id

  client_vnet_id   = var.use_existing ? data.azurerm_virtual_network.existing_client_vnet[0].id : azurerm_virtual_network.client_vnet[0].id
  client_vnet_name = var.use_existing ? data.azurerm_virtual_network.existing_client_vnet[0].name : azurerm_virtual_network.client_vnet[0].name
  client_subnet_id = var.use_existing ? data.azurerm_subnet.existing_client_subnet[0].id : azurerm_subnet.client_subnet[0].id

  # Get CIDR blocks for NSG rules
  dc_vnet_cidr     = var.use_existing ? data.azurerm_virtual_network.existing_dc_vnet[0].address_space[0] : var.dc_vnet_cidr
  client_vnet_cidr = var.use_existing ? data.azurerm_virtual_network.existing_client_vnet[0].address_space[0] : var.client_vnet_cidr

  # Resource group for NSGs (use existing RG if using existing VNets, otherwise use provided RG)
  nsg_resource_group = var.use_existing ? var.existing_resource_group_name : var.resource_group_name
}

# ============================================================================
# VNet Peering (created for both modes)
# ============================================================================

resource "azurerm_virtual_network_peering" "dc_to_client" {
  name                      = "${var.project_name}-dc-to-client"
  resource_group_name       = local.nsg_resource_group
  virtual_network_name      = local.dc_vnet_name
  remote_virtual_network_id = local.client_vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "client_to_dc" {
  name                      = "${var.project_name}-client-to-dc"
  resource_group_name       = local.nsg_resource_group
  virtual_network_name      = local.client_vnet_name
  remote_virtual_network_id = local.dc_vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# ============================================================================
# Network Security Group - Domain Controllers (created for both modes)
# ============================================================================

resource "azurerm_network_security_group" "dc_nsg" {
  name                = "${var.project_name}-dc-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Associate NSG with DC Subnet
resource "azurerm_subnet_network_security_group_association" "dc_subnet_nsg" {
  subnet_id                 = local.dc_subnet_id
  network_security_group_id = azurerm_network_security_group.dc_nsg.id
}

# DNS (TCP + UDP)
resource "azurerm_network_security_rule" "dc_dns_tcp" {
  name                        = "DNS-TCP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_dns_udp" {
  name                        = "DNS-UDP"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# LDAP (TCP + UDP) - CRITICAL for domain operations
resource "azurerm_network_security_rule" "dc_ldap_tcp" {
  name                        = "LDAP-TCP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "389"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_ldap_udp" {
  name                        = "LDAP-UDP"
  priority                    = 111
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "389"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# LDAPS
resource "azurerm_network_security_rule" "dc_ldaps" {
  name                        = "LDAPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "636"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# Global Catalog
resource "azurerm_network_security_rule" "dc_gc" {
  name                        = "Global-Catalog"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3268"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_gc_ssl" {
  name                        = "Global-Catalog-SSL"
  priority                    = 131
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3269"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# Kerberos (TCP + UDP)
resource "azurerm_network_security_rule" "dc_kerberos_tcp" {
  name                        = "Kerberos-TCP"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "88"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_kerberos_udp" {
  name                        = "Kerberos-UDP"
  priority                    = 141
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "88"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# Kerberos Password Change
resource "azurerm_network_security_rule" "dc_kerberos_pwd" {
  name                        = "Kerberos-Password"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "464"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# SMB/CIFS
resource "azurerm_network_security_rule" "dc_smb" {
  name                        = "SMB"
  priority                    = 160
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# RPC
resource "azurerm_network_security_rule" "dc_rpc" {
  name                        = "RPC"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "135"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# Dynamic RPC Ports
resource "azurerm_network_security_rule" "dc_rpc_dynamic" {
  name                        = "RPC-Dynamic"
  priority                    = 180
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "49152-65535"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# NetBIOS
resource "azurerm_network_security_rule" "dc_netbios_name" {
  name                        = "NetBIOS-Name"
  priority                    = 190
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "137"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_netbios_datagram" {
  name                        = "NetBIOS-Datagram"
  priority                    = 191
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "138"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

resource "azurerm_network_security_rule" "dc_netbios_session" {
  name                        = "NetBIOS-Session"
  priority                    = 192
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "139"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# DHCP Server
resource "azurerm_network_security_rule" "dc_dhcp" {
  name                        = "DHCP"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "67"
  source_address_prefixes     = [local.dc_vnet_cidr, local.client_vnet_cidr]
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# RDP (from allowed IPs only)
resource "azurerm_network_security_rule" "dc_rdp" {
  count                       = length(var.allowed_rdp_ips) > 0 ? 1 : 0
  name                        = "RDP"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.allowed_rdp_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# WinRM HTTP (from allowed IPs only)
resource "azurerm_network_security_rule" "dc_winrm_http" {
  count                       = length(var.allowed_winrm_ips) > 0 ? 1 : 0
  name                        = "WinRM-HTTP"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5985"
  source_address_prefixes     = var.allowed_winrm_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# WinRM HTTPS (from allowed IPs only)
resource "azurerm_network_security_rule" "dc_winrm_https" {
  count                       = length(var.allowed_winrm_ips) > 0 ? 1 : 0
  name                        = "WinRM-HTTPS"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefixes     = var.allowed_winrm_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.dc_nsg.name
}

# ============================================================================
# Network Security Group - Domain Clients (created for both modes)
# ============================================================================

resource "azurerm_network_security_group" "client_nsg" {
  name                = "${var.project_name}-client-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Associate NSG with Client Subnet
resource "azurerm_subnet_network_security_group_association" "client_subnet_nsg" {
  subnet_id                 = local.client_subnet_id
  network_security_group_id = azurerm_network_security_group.client_nsg.id
}

# RDP (from allowed IPs only)
resource "azurerm_network_security_rule" "client_rdp" {
  count                       = length(var.allowed_rdp_ips) > 0 ? 1 : 0
  name                        = "RDP"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.allowed_rdp_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.client_nsg.name
}

# WinRM HTTP (from allowed IPs only)
resource "azurerm_network_security_rule" "client_winrm_http" {
  count                       = length(var.allowed_winrm_ips) > 0 ? 1 : 0
  name                        = "WinRM-HTTP"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5985"
  source_address_prefixes     = var.allowed_winrm_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.client_nsg.name
}

# WinRM HTTPS (from allowed IPs only)
resource "azurerm_network_security_rule" "client_winrm_https" {
  count                       = length(var.allowed_winrm_ips) > 0 ? 1 : 0
  name                        = "WinRM-HTTPS"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefixes     = var.allowed_winrm_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.client_nsg.name
}

# Allow all traffic from DC VNet (for domain operations)
resource "azurerm_network_security_rule" "client_from_dc_vnet" {
  name                        = "From-DC-VNet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.dc_vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.client_nsg.name
}
