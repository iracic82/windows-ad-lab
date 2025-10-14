#!/bin/bash
# ============================================================================
# AWS Deployment Script (Separate Workspace)
# ============================================================================

set -e

echo "========================================"
echo "AWS Windows AD Lab Deployment"
echo "========================================"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure (or aws configure sso)"
    exit 1
fi

echo -e "${GREEN}✓ AWS credentials configured${NC}"
aws sts get-caller-identity
echo ""

# Navigate to AWS workspace
cd terraform/aws

echo "========================================"
echo "Terraform Init"
echo "========================================"
terraform init

echo ""
echo "========================================"
echo "Terraform Plan"
echo "========================================"
terraform plan -out=aws-plan.tfplan

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
terraform apply aws-plan.tfplan

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
ansible all -i inventory/aws_windows.yml -m win_ping

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure AD: cd ansible && ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml"
echo "  2. Get RDP info: cd terraform/aws && terraform output rdp_connection_info"
echo "  3. Cleanup: cd terraform/aws && terraform destroy"
