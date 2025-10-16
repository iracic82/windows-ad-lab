#!/bin/bash
# ============================================================================
# Azure Deployment Script (Separate Workspace)
# ============================================================================

set -e

echo "========================================"
echo "Azure Windows AD Lab Deployment"
echo "========================================"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI not installed${NC}"
    exit 1
fi

# Target subscription
TARGET_SUB="57a5f4f0-e9e8-4886-a8d7-b73a3ea2aa8b"

# Login if needed
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Logging into Azure...${NC}"
    az login
fi

# Set subscription
echo -e "${YELLOW}Setting subscription: $TARGET_SUB${NC}"
az account set --subscription "$TARGET_SUB"

SUB_ID=$(az account show --query id -o tsv)
SUB_NAME=$(az account show --query name -o tsv)

echo -e "${GREEN}✓ Active Subscription:${NC}"
echo "  Name: $SUB_NAME"
echo "  ID:   $SUB_ID"
echo ""

if [ "$SUB_ID" != "$TARGET_SUB" ]; then
    echo -e "${RED}Error: Wrong subscription${NC}"
    exit 1
fi

# Navigate to Azure workspace
cd terraform/azure

echo "========================================"
echo "Terraform Init"
echo "========================================"
terraform init

echo ""
echo "========================================"
echo "Terraform Plan"
echo "========================================"
terraform plan -var-file="terraform.tfvars.azure" -out=azure-plan.tfplan

echo ""
read -p "Proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "========================================"
echo "Terraform Apply"
echo "========================================"
terraform apply azure-plan.tfplan

echo ""
echo -e "${GREEN}✓ Infrastructure deployed!${NC}"
echo ""
echo "Waiting 3 minutes for VMs..."
sleep 180

echo ""
echo "========================================"
echo "Testing Connectivity"
echo "========================================"
cd ../../ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i ../terraform/ansible/inventory/azure_windows.yml -m win_ping

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure AD: ansible-playbook -i ../terraform/ansible/inventory/azure_windows.yml playbooks/site.yml"
echo "  2. Get RDP info: cd ../terraform/azure && terraform output azure_rdp_connection_info"
echo "  3. Cleanup: cd ../terraform/azure && terraform destroy -var-file='terraform.tfvars.azure'"
