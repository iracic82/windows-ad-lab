# Terraform Azure Backend - Team Collaboration Guide

## Overview

This project uses **Azure Backend** for Terraform state management, enabling multiple team members to collaborate safely on infrastructure changes. The state is stored remotely in Azure Storage with automatic locking to prevent conflicts.

## Prerequisites

Before you can work with Terraform, you need:

1. **Azure CLI installed**
   ```bash
   # macOS
   brew install azure-cli

   # Windows
   winget install Microsoft.AzureCLI

   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **Azure credentials with access to the state storage**
   - Subscription: `57a5f4f0-e9e8-4886-a8d7-b73a3ea2aa8b`
   - Resource Group: `terraform-state-rg`
   - Storage Account: `tfstatedemoenablement`

3. **Terraform installed** (>= 1.0)
   ```bash
   terraform --version
   ```

## First-Time Setup

### 1. Clone the Repository

```bash
git clone https://github.com/iracic82/windows-ad-lab.git
cd windows-ad-lab
```

### 2. Authenticate with Azure

```bash
az login
```

This will open a browser window for authentication. After logging in:

```bash
# Verify you're using the correct subscription
az account show

# If needed, switch to the correct subscription
az account set --subscription "57a5f4f0-e9e8-4886-a8d7-b73a3ea2aa8b"
```

### 3. Initialize Terraform Backend

```bash
cd terraform/azure
terraform init
```

You should see:
```
Initializing the backend...
Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.
```

### 4. Create Your tfvars File

Copy the example configuration:

```bash
cp terraform.tfvars.azure.example terraform.tfvars.azure
```

Edit `terraform.tfvars.azure` with your specific settings (VPC IDs, passwords, etc.)

**IMPORTANT**: Never commit `terraform.tfvars.azure` - it contains sensitive data!

## Daily Workflow

### 1. Pull Latest Code

Always start by pulling the latest code:

```bash
git pull origin main
```

### 2. Check Current State

```bash
cd terraform/azure
terraform plan -var-file="terraform.tfvars.azure"
```

Terraform will:
- Automatically pull the latest state from Azure Storage
- Show you what changes would be made

### 3. Apply Changes

```bash
terraform apply -var-file="terraform.tfvars.azure"
```

During `apply`:
- Azure locks the state file (using blob lease)
- No one else can make changes until you're done
- State is automatically saved back to Azure Storage

### 4. Commit Your Terraform Code Changes

If you modified `.tf` files:

```bash
git add terraform/azure/
git commit -m "Description of your infrastructure changes"
git push origin main
```

**Remember**: Only commit `.tf` files, NOT:
- `terraform.tfvars.azure` (sensitive data)
- `.terraform/` directory
- `terraform.tfstate*` files

## How State Locking Works

### Scenario: Two People Working Simultaneously

**Person A** runs:
```bash
terraform apply -var-file="terraform.tfvars.azure"
```
- Azure locks the state file
- Person A can make changes

**Person B** tries to run:
```bash
terraform apply -var-file="terraform.tfvars.azure"
```
- Gets error: `Error acquiring the state lock`
- Must wait until Person A finishes

**After Person A completes**:
- Lock is automatically released
- Person B can now run their command
- Person B will see Person A's changes in the plan

### If Someone's Process Crashes

If a lock gets stuck (rare), you can force-unlock:

```bash
# Get the lock ID from the error message
terraform force-unlock <LOCK_ID>
```

**WARNING**: Only use this if you're SURE no one else is running Terraform!

## Viewing Current State

### See What's Deployed

```bash
terraform show
```

### List All Resources

```bash
terraform state list
```

### Check Specific Resource

```bash
terraform state show 'module.azure_domain_controllers[0].azurerm_windows_virtual_machine.vm'
```

## Backend Configuration Details

The backend is configured in `terraform/azure/main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "terraform-state-rg"
  storage_account_name = "tfstatedemoenablement"
  container_name       = "tfstate"
  key                  = "demo-enablement.tfstate"
}
```

### Where Is My State File?

Your state is stored at:
- **Azure Portal**: Storage Accounts → `tfstatedemoenablement` → Containers → `tfstate` → `demo-enablement.tfstate`
- **Azure CLI**:
  ```bash
  az storage blob list \
    --account-name tfstatedemoenablement \
    --container-name tfstate \
    --output table
  ```

## Troubleshooting

### Error: "Failed to get existing workspaces"

**Cause**: Not authenticated with Azure

**Solution**:
```bash
az login
az account set --subscription "57a5f4f0-e9e8-4886-a8d7-b73a3ea2aa8b"
```

### Error: "Backend initialization required"

**Cause**: `.terraform/` directory missing or backend config changed

**Solution**:
```bash
terraform init
```

### Error: "Error acquiring the state lock"

**Cause**: Someone else is running Terraform, or previous process crashed

**Solution**:
1. Wait 2-3 minutes for the lock to auto-release
2. If still locked, check with team members
3. As last resort (if you're certain no one is using it):
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

### Error: "Blob not found"

**Cause**: State file doesn't exist in Azure (first time)

**Solution**: This is normal for first-time setup. Just run:
```bash
terraform apply -var-file="terraform.tfvars.azure"
```

## Best Practices

### DO ✅

- Always run `git pull` before making changes
- Run `terraform plan` before `terraform apply`
- Communicate with team when doing major infrastructure changes
- Commit and push your `.tf` file changes
- Keep your Azure CLI authenticated (`az account show`)

### DON'T ❌

- Don't commit `terraform.tfvars.azure` files
- Don't force-unlock unless absolutely necessary
- Don't run `terraform apply` without reviewing the plan first
- Don't modify the backend configuration without team discussion
- Don't work on different branches without coordinating (state is shared!)

## Security Notes

### Access Control

Only team members with access to the Azure subscription can:
- Read the Terraform state
- Make infrastructure changes

### State File Contains Sensitive Data

The state file contains:
- Resource IDs
- IP addresses
- Some configuration values

**Access is controlled by**:
- Azure Storage Account access policies
- Azure RBAC (Role-Based Access Control)
- Subscription-level permissions

### Credentials in State

Passwords and secrets are stored encrypted in the state file. However:
- Don't store plain-text secrets in `.tf` files
- Use Azure Key Vault for production secrets
- Use `sensitive = true` for sensitive variables

## Advanced: Multiple Environments

If you need separate environments (dev/staging/prod):

### Option 1: Separate State Files (Terraform Workspaces)

```bash
# Create workspace
terraform workspace new dev
terraform workspace new prod

# Switch workspace
terraform workspace select dev

# Each workspace has its own state file in Azure
```

### Option 2: Separate Backend Configurations

Use different state keys per environment:

```hcl
# For dev
backend "azurerm" {
  key = "demo-enablement-dev.tfstate"
}

# For prod
backend "azurerm" {
  key = "demo-enablement-prod.tfstate"
}
```

## Getting Help

- **Terraform Azure Backend Docs**: https://developer.hashicorp.com/terraform/language/settings/backends/azurerm
- **Azure CLI Docs**: https://learn.microsoft.com/en-us/cli/azure/
- **Team Contact**: Check with the infrastructure team lead

## Quick Reference

```bash
# Authenticate
az login

# Initialize backend
cd terraform/azure
terraform init

# Check what would change
terraform plan -var-file="terraform.tfvars.azure"

# Apply changes
terraform apply -var-file="terraform.tfvars.azure"

# Destroy resources
terraform destroy -var-file="terraform.tfvars.azure"

# View current state
terraform show

# List resources
terraform state list
```

---

**Last Updated**: 2025-10-16
**Maintained By**: Infrastructure Team
