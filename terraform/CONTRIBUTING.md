# Contributing Guide

## For Team Members

This guide helps you get started with the Windows AD Lab Terraform project.

## Prerequisites

1. **Install Required Tools:**
   - [AWS CLI](https://aws.amazon.com/cli/)
   - [Terraform](https://www.terraform.io/downloads) >= 1.5.0
   - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (optional)

2. **AWS Access:**
   - Get AWS credentials from your team lead
   - Request Okta SSO access or standard AWS credentials

## Quick Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Demo-Windows/terraform
```

### 2. Configure AWS Credentials

#### Option A: Okta SSO (Recommended)

```bash
# Configure SSO
aws configure sso --profile okta-sso

# Follow the prompts:
# - SSO start URL: [provided by team lead]
# - SSO region: us-east-1
# - SSO registration scopes: sso:account:access
# - CLI default region: us-east-1
# - CLI default output format: json

# Login
aws sso login --profile okta-sso

# Test
aws sts get-caller-identity --profile okta-sso
```

#### Option B: Standard AWS Credentials

```bash
# Configure credentials
aws configure --profile myprofile

# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (us-east-1)
# - Default output format (json)

# Test
aws sts get-caller-identity --profile myprofile
```

### 3. Run Setup Script

```bash
# Run interactive setup
./setup.sh

# Follow prompts to configure:
# - AWS profile
# - VPC and subnets
# - Key pair
# - IP addresses
```

### 4. Manual Configuration

If you prefer manual setup:

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Required changes:**
- `aws_profile` - Your AWS profile name
- `vpc_id` - VPC ID (ask team lead or find in AWS Console)
- `subnet_dc1`, `subnet_dc2`, `subnet_clients` - Subnet IDs
- `key_name` - Your EC2 key pair name
- `domain_admin_password` - Choose a secure password
- `allowed_rdp_cidrs` - Your IP address
- `allowed_winrm_cidrs` - Your IP address

### 5. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy (confirm with 'yes')
terraform apply

# View outputs
terraform output
```

## Working with Different AWS Profiles

### Using Your Own Profile

Update `terraform.tfvars`:

```hcl
aws_profile = "your-profile-name"
```

### Temporary Profile Override

```bash
# Use different profile for one command
terraform plan -var="aws_profile=different-profile"
```

### Environment Variable

```bash
# Set profile via environment
export AWS_PROFILE=okta-sso
terraform plan
```

## Common Tasks

### Check AWS Authentication

```bash
# Verify credentials work
aws sts get-caller-identity --profile okta-sso

# If using SSO and session expired
aws sso login --profile okta-sso
```

### Find Available Resources

```bash
# List VPCs
aws ec2 describe-vpcs --profile okta-sso

# List subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --profile okta-sso

# List key pairs
aws ec2 describe-key-pairs --profile okta-sso

# Get your public IP
curl ifconfig.me
```

### Update Infrastructure

```bash
# Modify terraform.tfvars
vim terraform.tfvars

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### Connect to Instances

```bash
# View instance IPs
terraform output rdp_connection_info

# RDP connection (use output private/public IPs)
# Windows: mstsc /v:<ip-address>
# Mac: Use Microsoft Remote Desktop app
# Linux: rdesktop <ip-address>

# Credentials:
# Username: Administrator
# Password: (what you set in domain_admin_password)
```

### Run Ansible Playbook

```bash
# Change to Ansible directory
cd ../ansible

# Test connectivity (macOS users need OBJC_ variable)
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/aws_windows.yml -m win_ping

# Run role-based AD setup (auto-scales!)
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml

# This automatically:
# - Creates AD forest on DC1
# - Joins and promotes DC2, DC3, DC4... (any number)
# - Joins all clients to domain
```

### Clean Up Resources

```bash
# Destroy everything
terraform destroy

# Destroy specific resource
terraform destroy -target=aws_instance.clients[0]
```

## Troubleshooting

### Authentication Errors

```bash
# Error: "No valid credential sources found"
# Solution: Configure AWS credentials
aws configure sso --profile okta-sso

# Error: "The security token included in the request is expired"
# Solution: Re-login
aws sso login --profile okta-sso
```

### Resource Errors

```bash
# Error: "InvalidSubnet.NotFound"
# Solution: Verify subnet exists and you have access
aws ec2 describe-subnets --subnet-ids subnet-xxxxx --profile okta-sso

# Error: "InvalidKeyPair.NotFound"
# Solution: Create or import key pair
aws ec2 create-key-pair --key-name mykey --profile okta-sso
```

### Network Errors

```bash
# Error: Cannot RDP to instance
# Check: Security group allows your IP
# Check: Instance has public IP or you're on VPN
# Check: Windows Firewall settings

# Error: Cannot connect with Ansible
# Check: WinRM is enabled (should be via userdata)
# Check: Security group allows port 5985/5986
# Check: Your IP is in allowed_winrm_cidrs
```

## Best Practices

### Security

1. **Never commit `terraform.tfvars`** - Contains secrets
2. **Use strong passwords** - Minimum 12 characters
3. **Restrict IP access** - Only allow your IP in security groups
4. **Rotate credentials** - Change passwords regularly
5. **Use MFA** - Enable on AWS account

### Terraform

1. **Always run `plan` first** - Review changes before applying
2. **Use meaningful names** - Update `project_name` and `owner`
3. **Comment your changes** - Add notes for complex configurations
4. **Keep state safe** - Never delete `.tfstate` files
5. **Use workspaces** - For multiple environments

### Cost Management

1. **Stop unused instances** - Don't leave running overnight
2. **Right-size instances** - Use smaller types for testing
3. **Delete when done** - Run `terraform destroy`
4. **Monitor costs** - Check AWS Cost Explorer

## Git Workflow

### Making Changes

```bash
# Create feature branch
git checkout -b feature/my-changes

# Make your changes
vim some-file.tf

# Test changes
terraform plan

# Commit (never commit .tfvars!)
git add some-file.tf
git commit -m "Description of changes"

# Push
git push origin feature/my-changes

# Create pull request
```

### Updating from Main

```bash
# Get latest changes
git checkout main
git pull

# Merge into your branch
git checkout feature/my-changes
git merge main

# Resolve conflicts if any
terraform init  # Re-initialize if needed
```

## Getting Help

### Resources

- **README.md** - Full documentation
- **terraform.tfvars.example** - Configuration examples
- **AWS Documentation** - https://docs.aws.amazon.com/
- **Terraform Documentation** - https://www.terraform.io/docs

### Team Support

- **Slack Channel** - #infrastructure
- **Team Lead** - [Name/Email]
- **Wiki** - [Link to internal wiki]

### Common Questions

**Q: Which AWS profile should I use?**
A: Use `okta-sso` if you have SSO access, otherwise use your custom profile.

**Q: Can I use my own VPC?**
A: Yes, just update `vpc_id` and subnet IDs in `terraform.tfvars`.

**Q: How do I get a key pair?**
A: Create one: `aws ec2 create-key-pair --key-name mykey --profile okta-sso`

**Q: Why is my deployment failing?**
A: Check `terraform plan` output for errors. Common issues are wrong VPC/subnet IDs or authentication problems.

**Q: Can I change the number of DCs or clients?**
A: Yes! Update `domain_controller_count` and/or `client_count` in `terraform.tfvars`, run `terraform apply`, then run the Ansible playbook. It scales automatically!

**Q: How do I connect to instances?**
A: Use `terraform output rdp_connection_info` to get IP addresses and credentials.

## Examples

### Example terraform.tfvars (Team Member)

```hcl
# John's configuration
aws_region  = "eu-central-1"
aws_profile = "john-dev"
owner       = "John Doe"

vpc_id   = "vpc-0abc123def456"
subnets  = ["subnet-0123456789"]  # Single subnet is fine

# ⭐ Scale easily!
domain_controller_count = 2  # Start small for testing
client_count            = 1  # One client

key_name              = "john-laptop-key"
domain_admin_password = "SuperSecure123!"

allowed_rdp_cidrs    = ["203.0.113.10/32"]  # John's office IP
allowed_winrm_cidrs  = ["203.0.113.10/32"]
```

### Example Deployment Session

```bash
# 1. Setup
cd terraform
./setup.sh

# 2. Review config
cat terraform.tfvars

# 3. Initialize
terraform init

# 4. Plan
terraform plan | tee plan.txt

# 5. Apply
terraform apply

# 6. Get info
terraform output rdp_connection_info

# 7. Work with instances...

# 8. Clean up
terraform destroy
```

---

**Questions?** Ask in #infrastructure or contact your team lead.
