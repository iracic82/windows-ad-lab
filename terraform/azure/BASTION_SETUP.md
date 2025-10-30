# Bastion Host Setup Guide

## Overview

A new **reusable Linux VM module** has been created to deploy a bastion host in the existing Management VNet with automatic VNet peering to your DC and Client VNets.

## What Was Created

### 1. New Module: `modules/azure-linux-vm`
```
modules/azure-linux-vm/
├── main.tf       # Linux VM, NIC, Public IP
├── variables.tf  # Module inputs
└── outputs.tf    # Module outputs
```

**Features:**
- Supports Ubuntu/RHEL/CentOS
- SSH key or password authentication
- Cloud-init integration
- Dynamic or static private IPs
- Optional public IP

### 2. Cloud-init Template: `templates/bastion_cloud_init.tpl`

**Pre-configured with:**
- ✅ 5 admin users with SSH keys (including yours!)
- ✅ **Docker** + docker-compose
- ✅ **Ansible** (via PPA)
- ✅ **Terraform** (via HashiCorp repo)
- ✅ **Azure CLI**
- ✅ Sudoers configuration
- ✅ SSH hardening
- ✅ Python3, git, wget, etc.

### 3. VNet Peering (Automatic)

When enabled, creates **bidirectional** peering:
```
management_vnet (172.16.32.0/20)
    ↕ [Peered] ↕
dc_vnet (172.18.1.0/24)

management_vnet (172.16.32.0/20)
    ↕ [Peered] ↕
client_vnet (172.18.2.0/24)
```

✅ **No subnet overlap** - peering will work perfectly!

## How to Deploy

### Step 1: Configure Your SSH Key

Edit `terraform.tfvars.azure` and set:

```hcl
enable_bastion = true

bastion_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDvFb... iracic@infoblox.com"
```

### Step 2: Customize (Optional)

```hcl
bastion_vm_name          = "demo-bastion"
bastion_hostname         = "demo-bastion"
bastion_vm_size          = "Standard_B2s"        # 2 vCPU, 4GB RAM
bastion_private_ip       = ""                     # Leave empty for dynamic
bastion_admin_username   = "ubuntu"
bastion_disk_size        = 50
bastion_create_public_ip = true
```

### Step 3: Deploy

```bash
# Initialize (first time only)
terraform init

# Preview changes
terraform plan

# Deploy bastion + VNet peerings
terraform apply
```

## What Gets Deployed

### Resources Created:
1. **Linux VM** in Management VNet (servers subnet)
2. **Public IP** (if enabled)
3. **Network Interface** with static or dynamic IP
4. **4 VNet Peering** connections (bidirectional)

### Existing Resources (UNTOUCHED):
- ❌ NO changes to existing DCs
- ❌ NO changes to existing Clients
- ❌ NO changes to existing VNets
- ❌ NO changes to management_vnet

## After Deployment

### SSH to Bastion Host:

```bash
# Get connection info
terraform output bastion_ssh_connection

# Connect
ssh ubuntu@<BASTION_PUBLIC_IP>
```

### Verify Connectivity from Bastion:

```bash
# Ping DC1
ping 172.18.1.5

# Ping Client1
ping 172.18.2.5

# RDP to DC1 (if RDP client installed)
xfreerdp /v:172.18.1.5 /u:azureadmin
```

### Pre-installed Tools:

```bash
# Check Docker
docker --version

# Check Ansible
ansible --version

# Check Terraform
terraform --version

# Check Azure CLI
az --version
```

## Users with Access

The following users have SSH access to the bastion host:

1. **admin-dsmith** (Don)
2. **admin-stee** (Steven)
3. **admin-ytoh** (Albert)
4. **admin-ssalo** (Salo)
5. **admin-iracic** (Ivan) ← YOU!

All users are in the `system-admins` group with **passwordless sudo**.

## Disable Bastion

To remove the bastion host and VNet peerings:

```hcl
# In terraform.tfvars.azure
enable_bastion = false
```

Then run:
```bash
terraform apply
```

This will cleanly destroy the bastion VM and peerings **without affecting existing DCs/Clients**.

## Troubleshooting

### Cloud-init logs on the VM:
```bash
ssh ubuntu@<BASTION_IP>
sudo cat /var/log/cloud-init-output.log
```

### Check VNet peering status:
```bash
az network vnet peering list --resource-group Management --vnet-name management_vnet --output table
az network vnet peering list --resource-group demo-enablement-rg --vnet-name demo-enablement-dc-vnet --output table
```

### Test connectivity:
```bash
# From bastion to DC1
ping 172.18.1.5

# From bastion to Client1
ping 172.18.2.5
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│ Management VNet (172.16.32.0/20) [EXISTING]        │
│ Resource Group: Management                          │
│                                                     │
│  ┌──────────────────────────────────┐              │
│  │ Subnet: servers (172.16.32.0/23) │              │
│  │                                   │              │
│  │  ┌─────────────────────────┐     │              │
│  │  │ Bastion Host [NEW]      │     │              │
│  │  │ - Ubuntu 22.04          │     │              │
│  │  │ - Docker, Ansible, TF   │     │              │
│  │  │ - Public IP             │     │              │
│  │  └─────────────────────────┘     │              │
│  └──────────────────────────────────┘              │
└─────────────────┬───────────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    [Peering]         [Peering]
         │                 │
┌────────▼────────┐  ┌─────▼──────────┐
│ DC VNet         │  │ Client VNet    │
│ 172.18.1.0/24   │  │ 172.18.2.0/24  │
│                 │  │                │
│ - DC1 (.5)      │  │ - Client1 (.5) │
│ - DC2 (.6)      │  │ - Client2 (.6) │
└─────────────────┘  │ - Client3 (.7) │
                     │ - Client4 (.8) │
                     └────────────────┘
```

## Notes

- The bastion feature is **opt-in** via `enable_bastion` flag
- All resources use conditional creation (`count` parameter)
- VNet peering is automatically configured when bastion is enabled
- No existing resources are modified or destroyed
- The cloud-init template can be customized in `templates/bastion_cloud_init.tpl`

