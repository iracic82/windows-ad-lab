# Multi-Cloud Deployment Guide

Your project now supports **separate workspaces** for AWS and Azure!

## New Directory Structure

```
terraform/
├── aws/                    # AWS workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── templates/
│   └── modules -> ../modules (symlink)
│
├── azure/                  # Azure workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.azure
│   ├── templates/
│   └── modules -> ../modules (symlink)
│
└── modules/                # Shared modules
    ├── windows-instance/   (AWS)
    ├── azure-windows-vm/   (Azure)
    ├── security-groups/    (AWS)
    ├── azure-networking/   (Azure)
    ├── iam/                (AWS)
    └── ansible-inventory/  (Both)
```

## Deploy to Azure

```bash
./deploy-azure.sh
```

Or manually:
```bash
cd terraform/azure
terraform init
terraform apply -var-file="terraform.tfvars.azure"
```

## Deploy to AWS

```bash
./deploy-aws.sh
```

Or manually:
```bash
cd terraform/aws
terraform init
terraform apply
```

## Benefits

✅ No file renaming needed
✅ Independent state files
✅ Can deploy both simultaneously
✅ Clear separation of concerns
✅ Easy to switch between platforms

## Deploy Both Simultaneously

```bash
# Terminal 1: Deploy Azure
./deploy-azure.sh

# Terminal 2: Deploy AWS (after Azure starts)
./deploy-aws.sh
```

Both deployments create separate Ansible inventories:
- `ansible/inventory/azure_windows.yml`
- `ansible/inventory/aws_windows.yml`

## Configure Active Directory

### For Azure:
```bash
cd ansible
ansible-playbook -i inventory/azure_windows.yml playbooks/site.yml
```

### For AWS:
```bash
cd ansible
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

## Get Connection Info

### Azure:
```bash
cd terraform/azure
terraform output azure_rdp_connection_info
```

### AWS:
```bash
cd terraform/aws
terraform output rdp_connection_info
```

## Cleanup

### Azure:
```bash
cd terraform/azure
terraform destroy -var-file="terraform.tfvars.azure"
```

### AWS:
```bash
cd terraform/aws
terraform destroy
```

## Cost Comparison

Running both simultaneously for 8 hours:
- Azure: ~$8
- AWS: ~$13
- **Total: ~$21**

## State Files

Each workspace has its own state:
- `terraform/azure/.terraform/` and `terraform.tfstate`
- `terraform/aws/.terraform/` and `terraform.tfstate`

No conflicts!

---

**Ready to deploy!**
- Azure: `./deploy-azure.sh`
- AWS: `./deploy-aws.sh`
