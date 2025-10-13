#!/bin/bash

# Windows AD Lab - Terraform Setup Script
# This script helps you set up the Terraform configuration

set -e

echo "=========================================="
echo "Windows AD Lab - Terraform Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform.tfvars exists
if [ -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars already exists${NC}"
    read -p "Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Copy example file
echo "Creating terraform.tfvars from example..."
cp terraform.tfvars.example terraform.tfvars

echo -e "${GREEN}✓ terraform.tfvars created${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI found${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform found${NC}"
echo ""

# Ask for AWS profile
echo "Available AWS profiles:"
aws configure list-profiles 2>/dev/null || echo "No profiles configured"
echo ""
read -p "Enter AWS profile name (default: okta-sso): " AWS_PROFILE
AWS_PROFILE=${AWS_PROFILE:-okta-sso}

# Test AWS authentication
echo ""
echo "Testing AWS authentication with profile: $AWS_PROFILE"
if aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
    echo -e "${GREEN}✓ AWS authentication successful${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    echo "  Account ID: $ACCOUNT_ID"
else
    echo -e "${RED}✗ AWS authentication failed${NC}"
    echo "Please configure your AWS credentials first:"
    echo "  For SSO: aws configure sso --profile $AWS_PROFILE"
    echo "  For standard: aws configure --profile $AWS_PROFILE"
    exit 1
fi

# Update AWS profile in terraform.tfvars
sed -i.bak "s/aws_profile = \".*\"/aws_profile = \"$AWS_PROFILE\"/" terraform.tfvars
rm -f terraform.tfvars.bak

echo ""
echo "=========================================="
echo "Gathering AWS Information"
echo "=========================================="
echo ""

# Get VPCs
echo "Available VPCs:"
aws ec2 describe-vpcs \
    --profile "$AWS_PROFILE" \
    --query "Vpcs[*].[VpcId,CidrBlock,Tags[?Key=='Name'].Value|[0]]" \
    --output table || echo "No VPCs found"

echo ""
read -p "Enter VPC ID: " VPC_ID

if [ -n "$VPC_ID" ]; then
    # Update VPC in terraform.tfvars
    sed -i.bak "s/vpc_id = \".*\"/vpc_id = \"$VPC_ID\"/" terraform.tfvars
    rm -f terraform.tfvars.bak

    # Get subnets in the VPC
    echo ""
    echo "Subnets in VPC $VPC_ID:"
    aws ec2 describe-subnets \
        --profile "$AWS_PROFILE" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key=='Name'].Value|[0]]" \
        --output table || echo "No subnets found"

    echo ""
    read -p "Enter Subnet ID for DC1: " SUBNET_DC1
    read -p "Enter Subnet ID for DC2: " SUBNET_DC2
    read -p "Enter Subnet ID(s) for Clients (comma-separated): " SUBNET_CLIENTS

    if [ -n "$SUBNET_DC1" ]; then
        sed -i.bak "s/subnet_dc1 = \".*\"/subnet_dc1 = \"$SUBNET_DC1\"/" terraform.tfvars
        rm -f terraform.tfvars.bak
    fi

    if [ -n "$SUBNET_DC2" ]; then
        sed -i.bak "s/subnet_dc2 = \".*\"/subnet_dc2 = \"$SUBNET_DC2\"/" terraform.tfvars
        rm -f terraform.tfvars.bak
    fi

    if [ -n "$SUBNET_CLIENTS" ]; then
        # Convert comma-separated list to Terraform list format
        IFS=',' read -ra SUBNETS <<< "$SUBNET_CLIENTS"
        SUBNET_LIST="["
        for subnet in "${SUBNETS[@]}"; do
            subnet=$(echo "$subnet" | xargs) # trim whitespace
            SUBNET_LIST="$SUBNET_LIST\n  \"$subnet\","
        done
        SUBNET_LIST="${SUBNET_LIST%,}\n]"

        # This is complex for sed, so we'll just note it
        echo ""
        echo -e "${YELLOW}Note: Please manually update subnet_clients in terraform.tfvars${NC}"
        echo "with: $SUBNET_LIST"
    fi
fi

# Get key pairs
echo ""
echo "Available EC2 Key Pairs:"
aws ec2 describe-key-pairs \
    --profile "$AWS_PROFILE" \
    --query "KeyPairs[*].[KeyName,KeyType]" \
    --output table || echo "No key pairs found"

echo ""
read -p "Enter Key Pair name: " KEY_NAME
if [ -n "$KEY_NAME" ]; then
    sed -i.bak "s/key_name = \".*\"/key_name = \"$KEY_NAME\"/" terraform.tfvars
    rm -f terraform.tfvars.bak
fi

# Get current public IP
echo ""
echo "Getting your current public IP..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
if [ -n "$PUBLIC_IP" ]; then
    echo "Your public IP: $PUBLIC_IP"
    read -p "Allow RDP/WinRM from this IP? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i.bak "s/YOUR\.PUBLIC\.IP\.ADDRESS/$PUBLIC_IP/g" terraform.tfvars
        sed -i.bak "s/YOUR\.ANSIBLE\.HOST\.IP/$PUBLIC_IP/g" terraform.tfvars
        rm -f terraform.tfvars.bak
    fi
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review and edit terraform.tfvars with your specific values"
echo "2. Set a secure domain_admin_password"
echo "3. Run: terraform init"
echo "4. Run: terraform plan"
echo "5. Run: terraform apply"
echo ""
echo -e "${YELLOW}Important: Never commit terraform.tfvars to git!${NC}"
echo ""
