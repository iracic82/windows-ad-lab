# ============================================================================
# Azure Linux VM Module
# Creates: Public IP + NIC + NSG + Linux VM with cloud-init
# ============================================================================

# Create Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  count               = var.create_nsg ? 1 : 0
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name}-nsg"
    }
  )
}

# Create SSH Allow Rule
resource "azurerm_network_security_rule" "ssh" {
  count                       = var.create_nsg && length(var.allowed_ssh_cidrs) > 0 ? 1 : 0
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.vm_nsg[0].name
}

# Create Public IP
resource "azurerm_public_ip" "vm_public_ip" {
  count               = var.create_public_ip ? 1 : 0
  name                = "${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name}-pip"
    }
  )
}

# Create Network Interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip != "" ? "Static" : "Dynamic"
    private_ip_address            = var.private_ip != "" ? var.private_ip : null
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name}-nic"
    }
  )
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  count                     = var.create_nsg ? 1 : 0
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg[0].id
}

# Create Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.name
  computer_name       = var.hostname
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = var.ssh_public_key != "" ? true : false

  # SSH Key authentication (preferred)
  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key != "" ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }

  # Password authentication (fallback)
  admin_password = var.ssh_public_key == "" ? var.admin_password : null

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    name                 = "${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Cloud-init configuration
  custom_data = var.cloud_init_data != "" ? base64encode(var.cloud_init_data) : null

  tags = merge(
    var.common_tags,
    {
      Name = var.name
      Role = var.role
      OS   = "${var.image_offer}-${var.image_sku}"
    }
  )
}
