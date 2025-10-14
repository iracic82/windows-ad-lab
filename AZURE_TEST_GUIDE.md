# Azure Deployment Test Guide

This guide will walk you through testing the Azure deployment with NEW VNets.

## Prerequisites Completed

✅ Azure CLI installed (version 2.77.0)
✅ Configuration file created: `terraform/terraform.tfvars.azure`
✅ Deployment script created: `deploy-azure.sh`
✅ Your public IP detected and configured: `88.89.194.135/32`

## Quick Start (Automated)

### Option 1: One-Command Deployment

```bash
./deploy-azure.sh
```

This script will:
1. Check Azure CLI installation
2. Login to Azure (if needed)
3. Auto-configure your subscription ID
4. Run `terraform init`
5. Run `terraform plan` and show you what will be created
6. Ask for confirmation
7. Deploy the infrastructure
8. Test WinRM connectivity
9. Show next steps

### Option 2: Manual Step-by-Step

If you prefer to run commands manually:

#### Step 1: Login to Azure

```bash
az login
```

This opens your browser for authentication.

#### Step 2: Verify Subscription

```bash
# List subscriptions
az account list --output table

# Set subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"

# Verify
az account show --output table
```

#### Step 3: Update Configuration

Get your subscription ID and update `terraform/terraform.tfvars.azure`:

```bash
SUB_ID=$(az account show --query id -o tsv)
echo "Your Subscription ID: $SUB_ID"

# Update the config file (replace the placeholder)
cd terraform
sed -i.bak "s/REPLACE_WITH_YOUR_SUBSCRIPTION_ID/$SUB_ID/" terraform.tfvars.azure
```

#### Step 4: Initialize Terraform

```bash
cd terraform
terraform init
```

#### Step 5: Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars.azure"
```

**Review the plan!** It will show:
- 2 VNets (DC and Client)
- 2 Subnets
- 1 VNet peering
- 2 NSGs (with ~25 security rules)
- 3 VMs (2 DCs, 1 Client)
- 3 NICs
- 3 Public IPs
- 1 Resource Group

#### Step 6: Apply Deployment

```bash
terraform apply -var-file="terraform.tfvars.azure" -auto-approve
```

**Time:** ~5-10 minutes

#### Step 7: Wait for VMs to Initialize

```bash
sleep 180  # Wait 3 minutes
```

#### Step 8: Test Connectivity

```bash
cd ../ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/azure_windows.yml -m win_ping
```

**Expected output:**
```
dc1 | SUCCESS => { "changed": false, "ping": "pong" }
dc2 | SUCCESS => { "changed": false, "ping": "pong" }
client1 | SUCCESS => { "changed": false, "ping": "pong" }
```

#### Step 9: Deploy Active Directory

```bash
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml
```

**Time:** ~30-45 minutes

#### Step 10: Verify Deployment

```bash
# Check domain membership
ansible windows -i inventory/azure_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# All should return: corp.infolab
```

#### Step 11: Get Connection Info

```bash
cd ../terraform
terraform output azure_rdp_connection_info
```

## What Gets Deployed

### Network Architecture

```
Resource Group: windows-ad-lab-rg (East US)

DC VNet (10.0.0.0/16)           Client VNet (10.1.0.0/16)
├── DC Subnet (10.0.1.0/24)     ├── Client Subnet (10.1.1.0/24)
├── DC1 (10.0.1.5)              └── CLIENT1 (10.1.1.5)
├── DC2 (10.0.1.6)
└── DC NSG                      └── Client NSG

        └────── VNet Peering ──────┘
```

### Resources Created

| Resource Type | Count | Details |
|---------------|-------|---------|
| Resource Group | 1 | windows-ad-lab-rg |
| VNets | 2 | DC VNet + Client VNet |
| Subnets | 2 | One per VNet |
| VNet Peering | 2 | Bidirectional |
| NSGs | 2 | DC NSG + Client NSG |
| NSG Rules | ~25 | AD ports + RDP/WinRM |
| VMs | 3 | 2 DCs + 1 Client |
| NICs | 3 | One per VM |
| Public IPs | 3 | One per VM |
| OS Disks | 3 | 128GB Premium SSD |

### Costs

**Estimated monthly cost (if left running):**
- 2 × Standard_D2s_v3: ~$140/month
- 1 × Standard_B2s: ~$30/month
- 3 × Public IPs: ~$11/month
- 3 × 128GB Premium SSD: ~$60/month
- **Total: ~$241/month**

**Testing cost (8 hours):**
- ~$8

## Verification Checklist

After deployment, verify:

- [ ] Resource group exists: `az group show --name windows-ad-lab-rg`
- [ ] VNets created: `az network vnet list --resource-group windows-ad-lab-rg --output table`
- [ ] VNet peering active: `az network vnet peering list --resource-group windows-ad-lab-rg --vnet-name windows-ad-lab-dc-vnet --output table`
- [ ] VMs running: `az vm list --resource-group windows-ad-lab-rg --output table`
- [ ] Public IPs assigned: `az network public-ip list --resource-group windows-ad-lab-rg --output table`
- [ ] WinRM accessible: `ansible all -i inventory/azure_windows.yml -m win_ping`
- [ ] AD forest created: Check Ansible playbook output
- [ ] Domain membership: All systems in `corp.infolab`

## Troubleshooting

### Issue: "Subscription not found"

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Issue: "Quota exceeded"

Check quotas:
```bash
az vm list-usage --location eastus --output table
```

Request increase in Azure Portal.

### Issue: "WinRM timeout"

1. Wait 5 minutes after deployment
2. Check NSG rules allow your IP:
   ```bash
   az network nsg rule list \
     --resource-group windows-ad-lab-rg \
     --nsg-name windows-ad-lab-dc-nsg \
     --output table
   ```
3. Verify public IPs are assigned
4. Check VM extension status:
   ```bash
   az vm extension list \
     --resource-group windows-ad-lab-rg \
     --vm-name windows-ad-lab-DC1 \
     --output table
   ```

### Issue: "Terraform state locked"

```bash
cd terraform
rm -f .terraform.lock.hcl
terraform init -upgrade
```

## Cleanup

### Destroy Everything

```bash
cd terraform
terraform destroy -var-file="terraform.tfvars.azure" -auto-approve
```

**Time:** ~5 minutes

### Verify Cleanup

```bash
az group show --name windows-ad-lab-rg
# Should return: "ResourceGroupNotFound"
```

## Files Created

```
.
├── deploy-azure.sh                       # Automated deployment script
├── terraform/
│   ├── terraform.tfvars.azure           # Your configuration
│   ├── azure-main.tf                    # Azure resources
│   ├── azure-variables.tf               # Azure variables
│   ├── azure-outputs.tf                 # Azure outputs
│   └── modules/
│       ├── azure-networking/            # VNets, NSGs, peering
│       └── azure-windows-vm/            # VM deployment
└── ansible/
    └── inventory/
        └── azure_windows.yml            # Auto-generated inventory
```

## Next Steps After Testing

1. **Test existing VNets mode:**
   - Create VNets manually in Azure Portal
   - Update `terraform.tfvars.azure` with `azure_use_existing_vnets = true`
   - Redeploy

2. **Scale up:**
   - Increase `domain_controller_count = 5`
   - Increase `client_count = 3`
   - Run `terraform apply`

3. **Compare with AWS:**
   - Deploy to AWS with `terraform apply` (uses existing AWS VPC)
   - Compare architecture, costs, and performance

## Success Criteria

Deployment is successful when:

- ✅ `terraform apply` completes with 0 errors
- ✅ All VMs respond to `win_ping`
- ✅ Ansible playbook completes successfully
- ✅ All VMs are in `corp.infolab` domain
- ✅ Can RDP to any VM using domain credentials
- ✅ `nltest /dsgetdc:corp.infolab` works from all VMs

---

**Ready to deploy!** Run: `./deploy-azure.sh`
