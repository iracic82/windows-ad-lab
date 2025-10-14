# ✅ Workspace Setup Complete!

Your project now has **separate workspaces** for AWS and Azure deployments!

## What Was Done

### 1. Created Separate Directories
```
terraform/
├── aws/                    ← AWS workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── templates/
│   └── modules -> ../modules
│
├── azure/                  ← Azure workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.azure
│   ├── templates/
│   └── modules -> ../modules
│
└── modules/                ← Shared by both
    ├── windows-instance/
    ├── azure-windows-vm/
    ├── security-groups/
    ├── azure-networking/
    ├── iam/
    └── ansible-inventory/
```

### 2. Created Deployment Scripts
- `./deploy-azure.sh` - Deploy to Azure
- `./deploy-aws.sh` - Deploy to AWS

### 3. Benefits

✅ **No File Renaming** - Switch platforms instantly
✅ **Independent State** - No conflicts between AWS and Azure
✅ **Deploy Both Simultaneously** - Run both at the same time
✅ **Clear Separation** - Each workspace is self-contained
✅ **Easy to Use** - Just run the script for your platform

## How to Deploy

### Azure (Currently Running)
```bash
./deploy-azure.sh
```

This deploys:
- 2 DCs in VNet 10.0.0.0/16
- 1 Client in VNet 10.1.0.0/16
- VNet peering between them
- Subscription: f3c83d34-3cf7-454e-93e5-2d8f604289e3

### AWS (When Needed)
```bash
./deploy-aws.sh
```

This deploys:
- 2 DCs + 1 Client in existing VPC
- Uses existing subnets
- Security groups configured

## Switch Between Platforms

No renaming needed! Just `cd` to the workspace:

```bash
# Work with Azure
cd terraform/azure
terraform plan -var-file="terraform.tfvars.azure"

# Work with AWS
cd terraform/aws
terraform plan
```

## Deploy Both Simultaneously

Yes, you can run both at the same time!

```bash
# Terminal 1
./deploy-azure.sh

# Terminal 2 (in another terminal)
./deploy-aws.sh
```

Both will:
- Use separate Terraform state files
- Create separate Ansible inventories
- Not interfere with each other

## Ansible Inventories

Each platform creates its own inventory:

- Azure: `ansible/inventory/azure_windows.yml`
- AWS: `ansible/inventory/aws_windows.yml`

Configure AD for each:
```bash
# Azure
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml

# AWS
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

## Cleanup

### Azure
```bash
cd terraform/azure
terraform destroy -var-file="terraform.tfvars.azure"
```

### AWS
```bash
cd terraform/aws
terraform destroy
```

## Cost Estimation

Running both simultaneously:
- **Azure**: 2 DCs + 1 Client = ~$1/hour (~$8 for 8 hours)
- **AWS**: 2 DCs + 1 Client = ~$1.60/hour (~$13 for 8 hours)
- **Total**: ~$2.60/hour (~$21 for 8 hours testing)

## Project Structure

```
Demo-Windows/
├── deploy-azure.sh          ← Run this for Azure
├── deploy-aws.sh            ← Run this for AWS
├── DEPLOYMENT_GUIDE.md      ← Full documentation
├── WORKSPACE_SETUP_COMPLETE.md  ← This file
│
├── terraform/
│   ├── aws/                 ← AWS workspace
│   ├── azure/               ← Azure workspace
│   └── modules/             ← Shared modules
│
└── ansible/                 ← Works with both
    ├── inventory/
    │   ├── azure_windows.yml  (auto-generated)
    │   └── aws_windows.yml    (auto-generated)
    ├── roles/
    └── playbooks/
```

## Current Status

✅ Azure deployment is currently running
⏳ Terraform is installing providers
⏳ Next: Plan creation and confirmation

## Next Steps

1. **Wait for Azure deployment** (currently in progress)
2. **Test Azure connectivity** (automatic after deployment)
3. **Configure Active Directory** on Azure
4. **(Optional) Deploy AWS** using `./deploy-aws.sh`
5. **Compare** the two platforms

---

**No more file renaming! Each platform has its own workspace.** 🎉
