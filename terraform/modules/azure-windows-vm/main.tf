# ============================================================================
# Azure Windows VM Module
# Creates: Public IP + NIC + VM
# ============================================================================

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
  name                = "${var.vm_name_prefix}-${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.vm_name_prefix}-${var.name}-nic"
    }
  )
}

# Create Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "${var.vm_name_prefix}-${var.name}"
  computer_name       = upper(var.name)  # Windows computer name (must be ≤15 chars)
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = "azureadmin"  # Azure doesn't allow "Administrator"
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    name                 = "${var.vm_name_prefix}-${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_sku
    version   = "latest"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.vm_name_prefix}-${var.name}"
      Role = var.role
      OS   = "WindowsServer2022"
    }
  )
}

# Run Custom Script Extension to execute PowerShell setup
# Azure Windows VMs don't auto-execute custom_data like AWS userdata
locals {
  # Generate the PowerShell script content (remove <powershell> tags)
  ps_script_raw = templatefile(
    var.role == "domain_controller" ? "${path.root}/templates/dc_userdata.tpl" : "${path.root}/templates/client_userdata.tpl",
    var.role == "domain_controller" ? {
      computer_name         = upper(var.name)
      domain_admin_password = var.admin_password
    } : {
      computer_name         = upper(var.name)
      domain_admin_password = var.admin_password
      dc1_ip                = var.dc1_ip
    }
  )
  # Remove <powershell> and </powershell> tags
  ps_script_clean = trimspace(replace(replace(local.ps_script_raw, "<powershell>", ""), "</powershell>", ""))
}

resource "azurerm_virtual_machine_extension" "setup_script" {
  name                 = "${var.name}-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  # Write script to file first, then execute it
  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -Command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(local.ps_script_clean)}')) | Out-File -FilePath C:\\setup.ps1 -Encoding UTF8; powershell.exe -ExecutionPolicy Bypass -File C:\\setup.ps1\""
  })

  tags = var.common_tags
}
