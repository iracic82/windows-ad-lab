# Getting Started - Local Setup Guide

This guide provides step-by-step instructions for setting up your local machine to deploy the Windows Active Directory lab to AWS or Azure.

## Overview

After cloning this repository, you need to install:
1. Cloud CLI (AWS CLI or Azure CLI)
2. Terraform
3. Ansible and Python dependencies
4. Configure cloud credentials

**Estimated setup time:** 15-20 minutes

---

## Step 1: Clone the Repository

```bash
git clone <repository-url>
cd Demo-Windows
```

---

## Step 2: Install Required Tools

### A. AWS CLI (for AWS deployment)

**macOS:**
```bash
# Using Homebrew
brew install awscli

# Verify installation
aws --version  # Should show version 2.x
```

**Linux:**
```bash
# Using official installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

**Windows:**
```powershell
# Download and run installer from:
# https://awscli.amazonaws.com/AWSCLIV2.msi

# Or using Chocolatey
choco install awscli

# Verify installation
aws --version
```

### B. Azure CLI (for Azure deployment)

**macOS:**
```bash
# Using Homebrew
brew install azure-cli

# Verify installation
az --version
```

**Linux:**
```bash
# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# RHEL/CentOS/Fedora
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y azure-cli

# Verify installation
az --version
```

**Windows:**
```powershell
# Download and run installer from:
# https://aka.ms/installazurecliwindows

# Or using Chocolatey
choco install azure-cli

# Verify installation
az --version
```

### C. Terraform

**macOS:**
```bash
# Using Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform --version  # Should be >= 1.0
```

**Linux:**
```bash
# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# RHEL/CentOS/Fedora
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform

# Verify installation
terraform --version
```

**Windows:**
```powershell
# Using Chocolatey
choco install terraform

# Or download binary from:
# https://www.terraform.io/downloads

# Verify installation
terraform --version
```

### D. Ansible + Python Dependencies

**macOS/Linux:**
```bash
# Install Python 3 (if not already installed)
python3 --version  # Should be >= 3.8

# Install pip if needed
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py

# Install Ansible
python3 -m pip install ansible

# Install WinRM library (required for Windows management)
python3 -m pip install pywinrm

# Install Ansible collections
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad

# Verify installation
ansible --version  # Should be >= 2.12
```

**Windows (WSL2 recommended):**
```powershell
# Option 1: Install WSL2 and use Linux instructions above
wsl --install
# Then follow Linux instructions

# Option 2: Native Windows (not recommended for Ansible)
# Install Python 3 from https://www.python.org/downloads/
python -m pip install ansible pywinrm
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad
```

---

## Step 3: Configure Cloud Credentials

### AWS Configuration

**Option A: SSO Login (Recommended for Corporate Accounts)**
```bash
# Configure SSO profile
aws configure sso

# Follow prompts:
# - SSO start URL: https://your-company.awsapps.com/start
# - SSO Region: us-east-1 (or your region)
# - Select account and role
# - CLI default region: eu-central-1 (or your preferred region)
# - Profile name: okta-sso (or any name)

# Login
aws sso login --profile okta-sso

# Verify
aws sts get-caller-identity --profile okta-sso
```

**Option B: Access Keys (Recommended for Personal Accounts)**
```bash
# Configure credentials
aws configure

# Enter when prompted:
# - AWS Access Key ID: [your-access-key]
# - AWS Secret Access Key: [your-secret-key]
# - Default region: eu-central-1 (or your preferred region)
# - Default output format: json

# Verify
aws sts get-caller-identity
```

**Update terraform.tfvars:**
```bash
cd terraform/aws

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
vim terraform.tfvars

# Set your AWS profile name:
aws_profile = "okta-sso"  # or "default" if using access keys
```

### Azure Configuration

```bash
# Login to Azure
az login

# Browser will open for authentication
# After login, you'll see your subscriptions listed

# If you have multiple subscriptions, set the default
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

**Update terraform.tfvars.azure:**
```bash
cd terraform/azure

# Copy example configuration
cp terraform.tfvars.azure.example terraform.tfvars.azure

# Edit with your settings
vim terraform.tfvars.azure

# Set your subscription ID (from: az account show)
azure_subscription_id = "12345678-1234-1234-1234-123456789abc"
```

---

## Step 4: Get Your Public IP (for Security Groups)

```bash
# Get your public IP
curl ifconfig.me
# Example output: 203.0.113.42

# Or alternative methods:
curl icanhazip.com
curl api.ipify.org
```

**Update terraform.tfvars (AWS or Azure):**
```hcl
# Allow only your IP for RDP and WinRM
allowed_rdp_cidrs   = ["203.0.113.42/32"]
allowed_winrm_cidrs = ["203.0.113.42/32"]
```

---

## Step 5: Configure Terraform Variables

### AWS (terraform/aws/terraform.tfvars)

AWS supports **5 deployment scenarios** - choose one:

**Option 1: Single Existing VPC (Simplest)**
```hcl
aws_region  = "eu-central-1"
aws_profile = "okta-sso"

# Use existing VPC for everything
use_existing_vpcs = true
use_separate_vpcs = false
vpc_id  = "vpc-xxxxxxxxxxxxx"
subnets = ["subnet-xxxxxxxxxxxxx"]

domain_controller_count = 2
client_count            = 2
domain_name             = "corp.infolab"
domain_admin_password   = "P@ssw0rd123!SecureAD"
key_name                = "your-key-pair-name"
allowed_rdp_cidrs       = ["YOUR.IP.HERE/32"]
allowed_winrm_cidrs     = ["YOUR.IP.HERE/32"]
```

**Option 2: Existing DC VPC + New Client VPC (Recommended)**
```hcl
aws_region  = "eu-central-1"
aws_profile = "okta-sso"

# Multi-VPC with peering
use_existing_vpcs = false
use_separate_vpcs = true
create_dc_vpc     = false  # Use existing
create_client_vpc = true   # Create new

# Existing DC VPC
existing_dc_vpc_id = "vpc-0a7299af0067aff53"
existing_dc_subnets = [
  "subnet-0a9f063607662c0f0",
  "subnet-0d0044ce1fabf4833"
]

# New Client VPC (Terraform creates)
client_vpc_cidr    = "10.11.0.0/16"
client_subnet_cidr = "10.11.11.0/24"

# IP Customization (optional)
dc_private_ips     = ["10.10.10.10", "10.10.10.71"]
client_private_ips = ["10.11.11.5", "10.11.11.6"]

domain_controller_count = 2
client_count            = 2
domain_name             = "corp.infolab"
domain_admin_password   = "P@ssw0rd123!SecureAD"
key_name                = "infoblox-tme"
allowed_rdp_cidrs       = ["YOUR.IP.HERE/32"]
allowed_winrm_cidrs     = ["YOUR.IP.HERE/32"]
```

**See terraform/aws/terraform.tfvars.example for all 5 scenarios**

### Azure (terraform/azure/terraform.tfvars.azure)

```hcl
# Azure Configuration
azure_subscription_id = "12345678-abcd-1234-abcd-123456789abc"
azure_location        = "eastus"  # Your Azure region

# Scale
domain_controller_count = 2  # Start with 2 DCs
client_count            = 1  # Start with 1 client

# Domain
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"  # Change this!

# Security
allowed_rdp_cidrs   = ["YOUR.IP.HERE/32"]
allowed_winrm_cidrs = ["YOUR.IP.HERE/32"]

# Network (creates new VNets by default)
azure_use_existing_vnets = false
azure_dc_vnet_cidr       = "10.0.0.0/16"
azure_dc_subnet_cidr     = "10.0.1.0/24"
azure_client_vnet_cidr   = "10.1.0.0/16"
azure_client_subnet_cidr = "10.1.1.0/24"

# VM Sizes (adjust based on budget)
azure_dc_vm_size     = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM
azure_client_vm_size = "Standard_B2s"     # 2 vCPU, 4GB RAM
```

---

## Step 6: Verify Setup

Run this checklist to ensure everything is installed:

```bash
# Cloud CLIs
aws --version        # Should show version 2.x
az --version         # Should show version 2.x

# Terraform
terraform --version  # Should be >= 1.0

# Ansible
ansible --version    # Should be >= 2.12
python3 -c "import winrm"  # Should not error

# Cloud credentials
aws sts get-caller-identity --profile okta-sso  # Shows your AWS account
az account show                                  # Shows your Azure subscription

# Your public IP
curl ifconfig.me     # Shows your IP address
```

---

## Step 7: Deploy Your First Lab

### Option A: AWS Deployment (Automated)

```bash
# From project root
./deploy-aws.sh

# Follow the prompts
# Wait ~20 minutes for full deployment
```

### Option B: Azure Deployment (Automated)

```bash
# From project root
./deploy-azure.sh

# Follow the prompts
# Wait ~20 minutes for full deployment
```

### Option C: Manual Deployment

**AWS:**
```bash
cd terraform/aws
terraform init
terraform plan
terraform apply -auto-approve
sleep 180  # Wait for VMs to boot

cd ../../ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES  # macOS only
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

**Azure:**
```bash
cd terraform/azure
terraform init
terraform plan -var-file="terraform.tfvars.azure"
terraform apply -var-file="terraform.tfvars.azure" -auto-approve
sleep 180  # Wait for VMs to boot

cd ../../ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES  # macOS only
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml
```

---

## Troubleshooting

### AWS CLI Issues

**Error: "Unable to locate credentials"**
```bash
# Re-run AWS configuration
aws configure sso
aws sso login --profile okta-sso
```

**Error: "You must specify a region"**
```bash
# Set default region
export AWS_DEFAULT_REGION=eu-central-1
# Or edit terraform.tfvars and set aws_region
```

### Azure CLI Issues

**Error: "No subscriptions found"**
```bash
# Re-login
az login
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Terraform Issues

**Error: "Failed to query available provider packages"**
```bash
# Reinitialize Terraform
cd terraform/aws  # or terraform/azure
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Ansible Issues

**Error: "winrm or requests is not installed"**
```bash
# Install Python dependencies
python3 -m pip install --upgrade pywinrm requests
```

**Error: "Failed to connect to WinRM"**
```bash
# Check security groups allow your IP
# Check VMs are running
# Wait 5 minutes after VM creation for WinRM to initialize
```

---

## Next Steps

Once setup is complete:

1. **Deploy the lab:** Use `./deploy-aws.sh` or `./deploy-azure.sh`
2. **Read the platform guide:**
   - AWS: [README.md](README.md)
   - Azure: [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)
3. **Test RDP access:** Get connection info from `terraform output`
4. **Scale the lab:** Adjust counts in `terraform.tfvars` and re-deploy

---

## Quick Reference

| Task | AWS Command | Azure Command |
|------|-------------|---------------|
| **Login** | `aws sso login --profile okta-sso` | `az login` |
| **Verify credentials** | `aws sts get-caller-identity` | `az account show` |
| **Deploy** | `./deploy-aws.sh` | `./deploy-azure.sh` |
| **Destroy** | `cd terraform/aws && terraform destroy` | `cd terraform/azure && terraform destroy -var-file='terraform.tfvars.azure'` |
| **Get RDP info** | `terraform output rdp_connection_info` | `terraform output azure_rdp_connection_info` |

---

## Cost Warning

**Running this lab incurs cloud charges!**

Estimated costs (running 24 hours):
- **AWS:** ~$15-20/day (2 DCs + 2 clients)
- **Azure:** ~$10-12/day (2 DCs + 1 client)

**Always destroy resources when done:**
```bash
# AWS
cd terraform/aws
terraform destroy -auto-approve

# Azure
cd terraform/azure
terraform destroy -var-file="terraform.tfvars.azure" -auto-approve
```

---

## Support

For issues:
1. **Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Comprehensive troubleshooting for AWS and Azure
2. **Review [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)** - Implementation details and critical fixes
3. **Open an issue** in the GitHub repository with detailed information

Deployment setup is now complete.
