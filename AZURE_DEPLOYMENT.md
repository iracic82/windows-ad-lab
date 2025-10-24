# Azure Deployment Guide - Windows Active Directory Lab

This guide covers deploying the Windows Active Directory lab on **Azure**. For **AWS deployment**, see [README.md](README.md).

## 📋 Quick Links

| Resource | Link |
|----------|------|
| **AWS Deployment** | [README.md](README.md) |
| **Platform Comparison** | [PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md) |
| **Getting Started** | [GETTING_STARTED.md](GETTING_STARTED.md) |
| **Troubleshooting** | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| **Technical Details** | [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) |

---

## Overview

Deploy a multi-DC Active Directory forest on Azure with:
- **Domain Controllers in dedicated VNet** (10.0.0.0/16)
- **Clients in separate VNet** (10.1.0.0/16)
- **Automatic VNet peering** between DC and Client VNets
- **Same Ansible playbooks** as AWS deployment
- **Lower cost** than AWS (~$295/month vs ~$500/month)

---

## Architecture

```
Azure Infrastructure:
├── DC VNet (10.0.0.0/16)
│   ├── DC Subnet (10.0.1.0/24)
│   ├── DC1 (10.0.1.5)
│   ├── DC2 (10.0.1.6)
│   └── DC3 (10.0.1.7) ...
│
├── Client VNet (10.1.0.0/16)
│   ├── Client Subnet (10.1.1.0/24)
│   ├── CLIENT1 (10.1.1.5)
│   └── CLIENT2 (10.1.1.6) ...
│
└── VNet Peering (DC VNet ↔ Client VNet)
```

**Key Features:**
- Separate VNets for DCs and Clients
- Automatic VNet peering configuration
- Network Security Groups (NSGs) with AD-specific rules
- Public IPs for RDP access
- Static private IPs for predictable addressing
- **Automatic resource tagging** for cost tracking and organization

---

## Resource Tagging

All Azure resources are automatically tagged for comprehensive tracking and cost management:

### Common Tags (Applied to ALL Resources)

| Tag | Description | Example | Configured In |
|-----|-------------|---------|---------------|
| **Project** | Project name | `windows-ad-lab` | `project_name` |
| **Environment** | Environment type | `demo`, `dev`, `test`, `prod` | `environment` |
| **ManagedBy** | Tool managing resources | `Terraform` | `managed_by` |
| **Creator** | Email of resource creator | `iracic@infoblox.com` | `creator` |
| **Owner** | Email of resource owner | `iracic@infoblox.com` | `owner` |
| **Purpose** | Purpose of deployment | `SalesEnablement` | `purpose` |
| **CostCenter** | Cost center for billing | `Enablement-Labs` | `cost_center` |
| **Department** | Owning department | `SolutionArchitecture` | `department` |
| **Lifecycle** | Resource lifecycle | `Persistent`, `Temporary`, `Ephemeral` | `resource_lifecycle` |

### VM-Specific Tags (In Addition to Common Tags)

| Tag | Description | Example |
|-----|-------------|---------|
| **Role** | VM role | `domain_controller`, `domain_client` |
| **OS** | Operating System | `WindowsServer2025` |
| **Name** | Resource name | `winadlab-dc1`, `winadlab-cl1` |

### VM Naming Convention

**Azure VM Names:**
- Domain Controllers: `winadlab-dc1`, `winadlab-dc2`, `winadlab-dc3`...
- Clients: `winadlab-cl1`, `winadlab-cl2`...

**Windows Computer Names:**
- Domain Controllers: `DC1`, `DC2`, `DC3`...
- Clients: `CL1`, `CL2`...

**Customization:**
Change `vm_name_prefix` in `terraform.tfvars.azure` to use different naming (e.g., `mylab`, `prod-ad`)

### Benefits

- **Cost Tracking**: Filter Azure Cost Management by `CostCenter`, `Purpose`, `Environment`
- **Resource Organization**: Group resources by `Project`, `Department`, `Environment`
- **Ownership**: Track who created/owns resources via `Creator` and `Owner` tags
- **Lifecycle Management**: Identify `Temporary` vs `Persistent` resources for cleanup
- **Automation**: Identify Terraform-managed resources via `ManagedBy` tag

**Customization:**
All tags are configurable in `terraform.tfvars.azure` (see Configuration Guide below).

---

## Prerequisites

### 1. Azure CLI & Authentication

```bash
# Install Azure CLI (if not already installed)
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows
# Download from: https://aka.ms/installazurecliwindows

# Login to Azure
az login

# Verify subscription
az account show

# Set subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Terraform

```bash
terraform --version  # >= 1.0 required
```

### 3. Ansible

```bash
ansible --version  # >= 2.12 required
python3 -m pip install pywinrm
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad
```

### 4. Get Your Public IP

```bash
curl ifconfig.me
# Example output: 203.0.113.42
```

---

## Configuration Guide

### Terraform Variables Overview

The Azure deployment uses `terraform/azure/terraform.tfvars.azure` for configuration. You have two deployment modes:

**Mode 1: Create New VNets (Default)**
- Terraform creates new VNets for DCs and clients
- Automatic VNet peering between DC and Client VNets
- Recommended for lab/demo environments

**Mode 2: Use Existing VNets**
- Deploy into your existing VNets
- Supports same VNet or different VNets
- Recommended for integration with existing infrastructure

---

## Quick Start

### Step 1: Configure Terraform Variables

```bash
cd terraform/azure

# Copy the example configuration
cp terraform.tfvars.azure.example terraform.tfvars.azure

# Edit the configuration
vim terraform.tfvars.azure
```

### Step 1a: Required Variables (Both Modes)

```hcl
# ===================================
# Azure Configuration
# ===================================
azure_subscription_id = "12345678-1234-1234-1234-123456789abc"  # From: az account show
azure_location        = "eastus"  # or westus2, northeurope, etc.

# ===================================
# Project Configuration & Tagging
# ===================================
project_name        = "windows-ad-lab"
vm_name_prefix      = "winadlab"        # Prefix for VM names (winadlab-dc1, winadlab-cl1)
environment         = "demo"            # demo, dev, test, prod
managed_by          = "Terraform"       # Tool managing resources
creator             = "your-email@example.com"
owner               = "your-email@example.com"
purpose             = "SalesEnablement"
cost_center         = "Enablement-Labs"
department          = "SolutionArchitecture"
resource_lifecycle  = "Persistent"      # Persistent, Temporary, Ephemeral

# ===================================
# Domain Configuration
# ===================================
domain_name           = "acme.corp"
domain_admin_password = "P@ssw0rd123!SecureAD"  # Change this!

# ===================================
# Scale Configuration
# ===================================
domain_controller_count = 2  # Number of Domain Controllers
client_count            = 1  # Number of Windows clients

# ===================================
# Security Configuration
# ===================================
# Your public IP (from: curl ifconfig.me)
allowed_rdp_cidrs   = ["203.0.113.42/32"]
allowed_winrm_cidrs = ["203.0.113.42/32"]
```

### Step 1b: Network Mode Selection

**Option A: Create New VNets (Default)**

```hcl
# ===================================
# Network Configuration - NEW VNets
# ===================================
azure_use_existing_vnets = false

# VNet CIDR blocks (Terraform will create these)
azure_dc_vnet_cidr       = "10.0.0.0/16"
azure_dc_subnet_cidr     = "10.0.1.0/24"
azure_client_vnet_cidr   = "10.1.0.0/16"
azure_client_subnet_cidr = "10.1.1.0/24"
```

**Option B: Use Existing VNets**

```hcl
# ===================================
# Network Configuration - EXISTING VNets
# ===================================
azure_use_existing_vnets = true

# Resource group containing your VNets
azure_existing_resource_group_name = "my-network-rg"

# DCs in one VNet
azure_existing_dc_vnet_name   = "hub-vnet"
azure_existing_dc_subnet_name = "dc-subnet"

# Clients in another VNet (or same VNet!)
azure_existing_client_vnet_name   = "spoke-vnet"  # Can be same as dc_vnet_name
azure_existing_client_subnet_name = "client-subnet"
```

**Common Scenarios:**

| Scenario | DC VNet | Client VNet | Peering | Use Case |
|----------|---------|-------------|---------|----------|
| **Separate VNets** | hub-vnet | spoke-vnet | Auto-created | Hub-spoke topology |
| **Same VNet, Different Subnets** | prod-vnet | prod-vnet | Not needed | Single VNet deployment |
| **Same VNet, Same Subnet** | shared-vnet | shared-vnet | Not needed | Simplest setup |

### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform with Azure provider
terraform init

# Deploy (specify the Azure tfvars file)
terraform apply -var-file="terraform.tfvars.azure" -auto-approve

# Wait for deployment (5-10 minutes)
# VMs will reboot automatically to apply hostnames
sleep 300
```

### Step 3: Verify Connectivity

```bash
# Terraform created: ansible/inventory/azure_windows.yml
cd ../ansible

# Test WinRM connectivity
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/azure_windows.yml -m win_ping

# Expected output:
# dc1 | SUCCESS => { "changed": false, "ping": "pong" }
# dc2 | SUCCESS => { "changed": false, "ping": "pong" }
# client1 | SUCCESS => { "changed": false, "ping": "pong" }
# client2 | SUCCESS => { "changed": false, "ping": "pong" }
```

### Step 4: Configure Active Directory

```bash
cd ansible

# Deploy AD (30-45 minutes)
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml

# What happens:
# 1. DC1 creates the forest (acme.corp)
# 2. DC2, DC3, ... join and promote automatically
# 3. CLIENT1, CLIENT2, ... join the domain
```

### Step 5: Install RSAT Modules (Optional)

If you need to install RSAT (Remote Server Administration Tools) modules for tools like Infoblox Universal DDI Agent, use the dedicated playbook:

```bash
cd ansible

# Install RSAT modules on all Windows hosts
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible-playbook -i ../terraform/ansible/inventory/azure_windows.yml playbooks/install-rsat.yml

# Or use the helper script
cd ..
./run-rsat-install.sh

# What gets installed:
# - RSAT-AD-PowerShell: Active Directory PowerShell cmdlets
# - RSAT-DNS-Server: DNS Server management tools
# - RSAT-DHCP: DHCP Server management tools
```

**What this does:**
- Installs RSAT modules on all domain controllers and clients
- Verifies installation success on each host
- Shows detailed summary of what was installed vs. already present

**Typical output:**
```
PLAY RECAP *********************************************************************
cl1     : ok=6    changed=1    unreachable=0    failed=0
cl2     : ok=6    changed=3    unreachable=0    failed=0
dc1     : ok=6    changed=1    unreachable=0    failed=0
dc2     : ok=6    changed=1    unreachable=0    failed=0
```

**Use cases:**
- Installing Infoblox Universal DDI Agent
- Remote management from client machines
- PowerShell-based AD/DNS/DHCP administration

See [RSAT Playbook Documentation](#rsat-remote-server-administration-tools) below for details.

### Step 6: Verify Deployment

```bash
# Check domain membership
ansible windows -i ../terraform/ansible/inventory/azure_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# All should return: acme.corp
```

### Step 7: RDP Access

```bash
# Get connection info
cd ../terraform
terraform output azure_rdp_connection_info

# Example output:
# Domain Controllers:
# - dc1: 20.30.40.50 (Private: 10.0.1.5)
# - dc2: 20.30.40.51 (Private: 10.0.1.6)
#
# Clients:
# - client1: 20.30.40.52 (Private: 10.1.1.5)
# - client2: 20.30.40.53 (Private: 10.1.1.6)
#
# Credentials:
# - Username: azureadmin
# - Password: P@ssw0rd123!SecureAD
# - Domain: acme.corp
```

**Connect via RDP:**
- **Host:** Public IP from output above
- **Username:** `acme.corp\azureadmin` or `azureadmin@acme.corp` (UPN format)
- **Password:** Your configured password

---

## Scaling

### Add More DCs (e.g., 2 → 5)

```bash
cd terraform

# Edit terraform.tfvars.azure
vim terraform.tfvars.azure

# Change:
domain_controller_count = 5  # was 2

# Apply changes
terraform apply -var-file="terraform.tfvars.azure" -auto-approve
sleep 180

# Configure new DCs with Ansible
cd ../ansible
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml

# DC1, DC2 will be skipped (already configured)
# DC3, DC4, DC5 will join and promote automatically
```

### Add More Clients (e.g., 2 → 5)

```bash
cd terraform
vim terraform.tfvars.azure

# Change:
client_count = 5  # was 2

terraform apply -var-file="terraform.tfvars.azure" -auto-approve
sleep 180

cd ../ansible
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml
```

---

## Cost Estimation (Azure)

**Example: 2 DCs + 2 Clients in East US**

| Resource | Quantity | Size | Monthly Cost |
|----------|----------|------|-------------|
| DC VMs | 2 | Standard_D2s_v3 (2 vCPU, 8GB) | ~$140 |
| Client VMs | 2 | Standard_B2s (2 vCPU, 4GB) | ~$60 |
| Public IPs | 4 | Standard | ~$15 |
| Storage | 4 | Premium SSD (128GB each) | ~$80 |
| **Total** | | | **~$295/month** |

**Save Money:**

```bash
# Stop VMs when not in use (storage still charged)
az vm deallocate --resource-group windows-ad-lab-rg --name windows-ad-lab-DC1
az vm deallocate --resource-group windows-ad-lab-rg --name windows-ad-lab-DC2
# ... repeat for all VMs

# Or destroy completely
cd terraform
terraform destroy -var-file="terraform.tfvars.azure" -auto-approve
```

---

## Network Configuration

### VNet Peering

The Terraform configuration automatically creates bidirectional VNet peering:

- **DC VNet → Client VNet** (peering connection)
- **Client VNet → DC VNet** (peering connection)

**This allows:**
- DCs can communicate with Clients across VNets
- Clients can authenticate against DCs
- No additional routing required

### Advanced: Using Existing VNets

See **Step 1b** in the Quick Start section above for detailed configuration options.

**Key Points:**
- ✅ Supports separate VNets (hub-spoke) or same VNet deployment
- ✅ VNet peering created automatically when VNets differ
- ✅ NSGs created and attached to your subnets
- ✅ VMs deployed with static IPs

**To find your existing VNet names:**
```bash
# List VNets in a resource group
az network vnet list --resource-group my-rg --output table

# List subnets in a VNet
az network vnet subnet list \
  --resource-group my-rg \
  --vnet-name my-vnet \
  --output table
```

**Important Notes:**
- NSGs will be created in the resource group specified in `azure_location` (for new deployments)
- If VNets are in the same resource group, set that as both `resource_group_name` and `azure_existing_resource_group_name`
- VNet peering requires appropriate permissions on both VNets

### Network Security Groups (NSGs)

**DC NSG (attached to DC subnet):**
- Allows all AD ports (LDAP, Kerberos, DNS, RPC, etc.) from both VNets
- Allows RDP/WinRM from your IP only

**Client NSG (attached to Client subnet):**
- Allows all traffic from DC VNet
- Allows RDP/WinRM from your IP only

---

## Troubleshooting

### Issue: "Subscription not found"

```bash
# Verify subscription
az account show

# List all subscriptions
az account list --output table

# Set correct subscription
az account set --subscription "SUBSCRIPTION_ID"
```

### Issue: "Quota exceeded"

Check your Azure quotas:
```bash
az vm list-usage --location eastus --output table
```

Request quota increase in Azure Portal if needed.

### Issue: "WinRM connection timeout"

1. Verify NSG rules allow your IP
2. Verify public IPs are assigned:
   ```bash
   terraform output azure_domain_controllers
   ```
3. Wait 3-5 minutes after deployment for WinRM to initialize
4. Check custom script extension status:
   ```bash
   az vm extension list --resource-group windows-ad-lab-rg --vm-name windows-ad-lab-DC1
   ```

### Issue: "Domain join fails"

Same troubleshooting as AWS (see main README.md):
- DNS configuration
- Network connectivity between VNets
- Verify VNet peering is active:
  ```bash
  az network vnet peering list \
    --resource-group windows-ad-lab-rg \
    --vnet-name windows-ad-lab-dc-vnet \
    --output table
  ```

---

## Cleanup

### Destroy All Resources

```bash
cd terraform

# Destroy everything
terraform destroy -var-file="terraform.tfvars.azure" -auto-approve

# Verify resource group is deleted
az group show --name windows-ad-lab-rg
# Should return: "ResourceGroupNotFound"
```

---

## Comparison: AWS vs Azure

| Feature | AWS | Azure |
|---------|-----|-------|
| **Networking** | VPC Peering | VNet Peering |
| **VMs** | EC2 | Azure VMs |
| **Public IPs** | Elastic IPs | Public IP Address |
| **Security** | Security Groups | Network Security Groups |
| **Userdata** | EC2 userdata | Custom Script Extension |
| **Cost (2 DCs + 2 Clients)** | ~$500/month | ~$295/month |

---

## Advanced Configuration

### Using Existing VNets

If you already have VNets, you can modify `terraform/azure-main.tf`:

1. Comment out VNet creation in `modules/azure-networking/main.tf`
2. Use data sources to reference existing VNets
3. Update subnet IDs in variables

### Custom Windows SKU

Change Windows version in `terraform.tfvars.azure`:

```hcl
azure_windows_sku = "2025-datacenter-g2"  # Windows Server 2025
# or
azure_windows_sku = "2019-datacenter-gensecond"  # Windows Server 2019
```

### Disable Public IPs

Edit `terraform/azure-main.tf`:

```hcl
module "azure_domain_controllers" {
  ...
  create_public_ip = false  # Change from true to false
  ...
}
```

Then use Azure Bastion or VPN for access.

---

## Security Considerations

**Current (Lab) Setup:**
- Windows Firewall disabled for simplicity
- Password in plaintext in tfvars
- Public IPs with RDP exposed

**For Production:**
1. Use Azure Key Vault for password storage
2. Enable Windows Firewall with AD rules
3. Use Azure Bastion instead of public IPs
4. Enable Azure Monitor and diagnostics
5. Use Managed Identities for authentication
6. Enable Azure AD Connect (hybrid identity)

---

## RSAT (Remote Server Administration Tools)

### Overview

The RSAT playbook installs Remote Server Administration Tools on all Windows hosts (domain controllers and clients). These tools provide PowerShell cmdlets and management capabilities for Active Directory, DNS, and DHCP.

**Location:** `ansible/playbooks/install-rsat.yml`

### When to Use

Install RSAT modules when you need:
- **Infoblox Universal DDI Agent** - Requires RSAT-AD-PowerShell, RSAT-DNS-Server, RSAT-DHCP
- **Remote management** - Manage AD/DNS/DHCP from client machines
- **PowerShell automation** - Use AD/DNS/DHCP cmdlets for scripting
- **Troubleshooting** - Query AD, DNS, or DHCP from any host

### Installed Modules

| Module | Description | Commands Provided |
|--------|-------------|-------------------|
| **RSAT-AD-PowerShell** | Active Directory PowerShell cmdlets | `Get-ADUser`, `Get-ADComputer`, `Get-ADGroup`, etc. |
| **RSAT-DNS-Server** | DNS Server management tools | `Get-DnsServerZone`, `Add-DnsServerResourceRecord`, etc. |
| **RSAT-DHCP** | DHCP Server management tools | `Get-DhcpServerv4Scope`, `Get-DhcpServerv4Lease`, etc. |

### Installation

**Method 1: Using the dedicated playbook**

```bash
cd ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible-playbook -i ../terraform/ansible/inventory/azure_windows.yml playbooks/install-rsat.yml
```

**Method 2: Using the helper script (with logging)**

```bash
./run-rsat-install.sh

# Monitor from another terminal:
tail -f ansible/rsat-installation-*.log
```

### What the Playbook Does

1. **Verifies WinRM connectivity** to all hosts
2. **Installs RSAT-AD-PowerShell** on all Windows hosts
3. **Installs RSAT-DNS-Server** on all Windows hosts
4. **Installs RSAT-DHCP** on all Windows hosts
5. **Verifies installation** by querying Windows Features
6. **Displays summary** showing what was installed vs. already present

### Example Output

```
PLAY [Install RSAT Modules on All Windows Hosts] *******************************

TASK [Verify WinRM connectivity] ***********************************************
ok: [dc1]
ok: [dc2]
ok: [cl1]
ok: [cl2]

TASK [Install RSAT-AD-PowerShell module] ***************************************
ok: [dc1]
ok: [dc2]
changed: [cl1]
changed: [cl2]

TASK [Install RSAT-DNS-Server module] ******************************************
ok: [dc1]
ok: [dc2]
changed: [cl1]
changed: [cl2]

TASK [Install RSAT-DHCP module] ************************************************
ok: [dc1]
ok: [dc2]
changed: [cl1]
changed: [cl2]

TASK [Verify RSAT modules are installed] ***************************************
changed: [dc1]
changed: [dc2]
changed: [cl1]
changed: [cl2]

TASK [Display RSAT installation results] ***************************************
ok: [dc1] => {
    "msg": [
        "=== RSAT Installation Summary for dc1 ===",
        "RSAT-AD-PowerShell: Already Present",
        "RSAT-DNS-Server: Already Present",
        "RSAT-DHCP: Already Present",
        "",
        "=== Verification Status ===",
        [
            "RSAT-AD-PowerShell : True",
            "RSAT-DNS-Server : True",
            "RSAT-DHCP : True"
        ]
    ]
}

PLAY RECAP *********************************************************************
cl1     : ok=6    changed=4    unreachable=0    failed=0
cl2     : ok=6    changed=4    unreachable=0    failed=0
dc1     : ok=6    changed=1    unreachable=0    failed=0
dc2     : ok=6    changed=1    unreachable=0    failed=0
```

### Verification

Verify RSAT modules are installed on any host:

```bash
# Using Ansible
ansible dc1 -i ../terraform/ansible/inventory/azure_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-WindowsFeature RSAT-AD-PowerShell,RSAT-DNS-Server,RSAT-DHCP | Select-Object Name, InstallState"

# Using Azure CLI (from local machine)
az vm run-command invoke \
  --resource-group DEMO-ENABLEMENT-RG \
  --name demo-dc1 \
  --command-id RunPowerShellScript \
  --scripts "Get-WindowsFeature RSAT-AD-PowerShell,RSAT-DNS-Server,RSAT-DHCP | Select-Object Name, InstallState"
```

Expected output:
```
Name               InstallState
----               ------------
RSAT-AD-PowerShell Installed
RSAT-DNS-Server    Installed
RSAT-DHCP          Installed
```

### Playbook Details

**Location:** `ansible/playbooks/install-rsat.yml`

**Target hosts:** All Windows hosts (group: `windows`)
- Domain Controllers: dc1, dc2, dc3, ...
- Clients: cl1, cl2, cl3, ...

**Idempotency:**
- ✅ Safe to run multiple times
- ✅ Only installs missing modules
- ✅ Shows "Already Present" for existing modules

**Execution time:**
- ~3-5 minutes for 6 hosts
- DHCP module takes the longest (2-4 minutes per host)

### Files Created

| File | Purpose |
|------|---------|
| `ansible/playbooks/install-rsat.yml` | Main RSAT installation playbook |
| `run-rsat-install.sh` | Helper script with logging |
| `ansible/rsat-installation-*.log` | Installation logs (created by helper script) |

### Troubleshooting

**Issue: "Feature name RSAT-* is unknown"**
- RSAT modules require Windows Server 2016 or newer
- Verify Windows version: `ansible all -m ansible.windows.win_shell -a "Get-ComputerInfo | Select-Object WindowsProductName"`

**Issue: Playbook hangs on DHCP installation**
- Normal behavior - DHCP module takes 2-4 minutes per host
- Monitor progress: Check CPU usage on VMs via Azure Portal
- Wait at least 10 minutes before canceling

**Issue: Installation fails with permission error**
- Verify you're using domain admin credentials
- Check inventory file has correct `domain_admin_user` and `domain_admin_password`

### Performance Impact

RSAT modules are lightweight management tools:
- **Disk space:** ~50 MB per module (~150 MB total)
- **Memory:** No additional memory usage (only when cmdlets are used)
- **Performance:** No performance impact on server operations
- **Services:** No additional services running

Safe to install on all servers without performance concerns.

---

## Next Steps

- [Main README](README.md) - Project overview
- [AWS Deployment](terraform/main.tf) - AWS version
- [Ansible Roles](ansible/roles/) - AD configuration
- [RSAT Playbook](ansible/playbooks/install-rsat.yml) - RSAT installation

---

## Support

For issues specific to Azure deployment, check:
- [Azure Terraform Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure VM Documentation](https://docs.microsoft.com/azure/virtual-machines/)
