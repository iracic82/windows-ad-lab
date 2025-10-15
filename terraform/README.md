# Windows Active Directory Lab - Terraform Infrastructure

This Terraform project deploys a **scalable** Windows Active Directory environment on **AWS** or **Azure** with:
- **N Domain Controllers** (1-100+, auto-scales) with AD, DNS, and DHCP
- **M Windows Client machines** (0-100+, configurable)
- Automatic Ansible inventory generation
- Full security configuration (Security Groups/NSGs)
- **Multi-cloud support** with shared modules
- **Role-based Ansible** that automatically scales with your infrastructure

## Multi-Cloud Architecture

**🌐 Two Deployment Options:**

1. **AWS** - Deploy to existing VPC (`terraform/aws/` workspace)
2. **Azure** - Deploy with VNet peering (`terraform/azure/` workspace)

**⭐ Scalable Design:** Supports ANY number of DCs and clients on both platforms!

### Workspace Structure

```
terraform/
├── aws/                      # AWS workspace (separate state)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars      # AWS configuration
│   └── modules -> ../modules # Symlink to shared modules
│
├── azure/                    # Azure workspace (separate state)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.azure  # Azure configuration
│   └── modules -> ../modules   # Symlink to shared modules
│
└── modules/                  # Shared modules
    ├── windows-instance/     # AWS EC2 instances
    ├── security-groups/      # AWS security groups
    ├── iam/                  # AWS IAM roles
    ├── azure-networking/     # Azure VNets + NSGs
    ├── azure-windows-vm/     # Azure VMs
    └── ansible-inventory/    # Cross-platform inventory generation
```

**Key Design:**
- Separate workspaces = independent state files
- Shared modules via symlinks = code reuse
- Platform-specific modules for cloud differences
- Cross-platform Ansible inventory module

## AWS Architecture

**Best for:** Organizations with existing AWS infrastructure

### Multi-VPC Support (NEW!)

The AWS deployment now supports **5 flexible deployment scenarios:**

**Scenario 1: Single VPC (Same VPC for DCs and Clients)**
```
VPC (10.10.0.0/16)
├── Subnet 1
│   ├── DC1 (10.10.10.5) - Forest Root
│   ├── DC2 (10.10.10.6) - Additional DC + Global Catalog
│   └── Clients (10.10.10.7+)
└── Subnet 2 (optional, HA deployment)
```

**Scenario 2-5: Separate VPCs with Peering**
```
DC VPC (10.10.0.0/16)              Client VPC (10.11.0.0/16)
├── DC Subnet                       ├── Client Subnet
├── DC1 (10.10.10.10)              ├── CLIENT1 (10.11.11.5)
├── DC2 (10.10.10.71)              └── CLIENT2 (10.11.11.6)
└───── VPC Peering (automatic) ─────┘
```

**Supported Scenarios:**
1. **Existing VPC** - DCs and Clients in same existing VPC
2. **New VPC** - Create new VPC for both DCs and Clients
3. **New DC VPC + New Client VPC** - Create both VPCs
4. **Existing DC VPC + New Client VPC** - Use existing DC VPC, create Client VPC
5. **New DC VPC + Existing Client VPC** - Create DC VPC, use existing Client VPC

**Key Features:**
- First DC automatically becomes forest root
- Additional DCs join domain and promote automatically
- All DCs are Global Catalog servers
- Automatic VPC peering when using separate VPCs
- Full cross-VPC connectivity with security groups
- Flexible IP address customization

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with your profile
3. **Terraform** >= 1.5.0
4. **Ansible** (optional, for configuration)
5. **VPC** already created in AWS
6. **EC2 Key Pair** for RDP access

## Azure Architecture

**Best for:** Lower costs, native Microsoft integration

```
DC VNet (10.0.0.0/16)           Client VNet (10.1.0.0/16)
├── DC Subnet (10.0.1.0/24)     ├── Client Subnet (10.1.1.0/24)
├── DC NSG                       ├── Client NSG
├── DC1 (10.0.1.5)              ├── CLIENT1 (10.1.1.5)
├── DC2 (10.0.1.6)              └── CLIENT2 (10.1.1.6) ...
└── DC3 (10.0.1.7) ...
        └────── VNet Peering ──────┘
```

**Key Features:**
- Network separation by default
- Automatic VNet peering
- Lower cost (~$295/month vs ~$500/month for AWS)

## Deployment Guides

| Platform | Workspace | Guide |
|----------|-----------|-------|
| **AWS** | `terraform/aws/` | [README.md](../README.md) |
| **Azure** | `terraform/azure/` | [AZURE_DEPLOYMENT.md](../AZURE_DEPLOYMENT.md) |

---

## Quick Start - AWS

### 1. Configure Your AWS Profile

#### Option A: Using Okta SSO
```bash
# Configure Okta SSO profile
aws configure sso --profile okta-sso

# Test authentication
aws sts get-caller-identity --profile okta-sso
```

#### Option B: Using Default Profile
```bash
# Configure default credentials
aws configure

# Test authentication
aws sts get-caller-identity
```

#### Option C: Using Custom Profile
```bash
# Configure custom profile
aws configure --profile myprofile

# Test authentication
aws sts get-caller-identity --profile myprofile
```

### 2. Setup Terraform Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Required values to update:**
- `aws_profile` - Your AWS CLI profile name
- `vpc_id` - Your VPC ID
- `subnets` - List of subnet IDs (1+ subnets, round-robin distribution)
- `domain_controller_count` - Number of DCs (1-100+)
- `client_count` - Number of clients (0-100+)
- `key_name` - Your EC2 key pair name
- `domain_admin_password` - Secure password for domain admin
- `allowed_rdp_cidrs` - Your IP address for RDP access
- `allowed_winrm_cidrs` - Your IP address for Ansible/WinRM

### 3. Get Required AWS Information

```bash
# Find your VPC ID
aws ec2 describe-vpcs --profile okta-sso

# Find subnets in your VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-YOUR-VPC-ID" \
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" \
  --output table \
  --profile okta-sso

# List your key pairs
aws ec2 describe-key-pairs --profile okta-sso

# Get your current public IP
curl -s ifconfig.me
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes 15-20 minutes)
terraform apply

# View outputs
terraform output
```

## Configuration

### Network Configuration

The infrastructure uses flexible network configuration:

```hcl
# Single subnet deployment (not recommended)
subnet_clients = ["subnet-xxxxx"]

# Multi-subnet deployment (recommended)
subnet_clients = [
  "subnet-xxxxx",  # AZ-A
  "subnet-yyyyy"   # AZ-B
]
```

Clients are distributed across subnets in round-robin fashion.

### IP Address Configuration (NEW!)

The infrastructure supports both **manual** and **automatic** IP assignment for all instances.

**Option 1: Manual IP Assignment (Recommended for Production)**
```hcl
# Specify exact IPs for Domain Controllers
dc_private_ips = ["10.10.10.10", "10.10.10.71"]

# Specify exact IPs for Clients
client_private_ips = ["10.11.11.5", "10.11.11.6"]
```

**Option 2: Automatic IP Assignment (Simplest)**
```hcl
# Leave empty to auto-calculate IPs
dc_private_ips     = []  # Will use dc_ip_start_offset
client_private_ips = []  # Will use client_ip_start_offset
```

**Option 3: Automatic with Custom Offsets**
```hcl
# Control starting IP addresses
dc_ip_start_offset     = 10  # DCs get .10, .11, .12...
client_ip_start_offset = 20  # Clients get .20, .21, .22...

dc_private_ips     = []  # Empty = auto-calculate
client_private_ips = []  # Empty = auto-calculate
```

**Important Notes:**
- Manual IPs must be within your subnet ranges
- For /28 subnets: avoid .0 (network) and .15/.31/.etc (broadcast)
- Manual IPs take precedence over automatic calculation
- DCs should always have static IPs for DNS stability

### Instance Configuration

```hcl
# Instance types
dc_instance_type     = "t3.large"   # For DCs
client_instance_type = "t3.medium"  # For clients

# ⭐ SCALE HERE! ⭐
domain_controller_count = 3  # 1-100+ DCs (scales automatically!)
client_count            = 2  # 0-100+ clients

# Volume size
root_volume_size = 100  # GB
```

**Scaling is easy:**
- Want 5 DCs? Change `domain_controller_count = 5`
- Want 10 clients? Change `client_count = 10`
- Terraform + Ansible handle everything automatically!

### Security Configuration

**RDP Access:**
```hcl
# Single IP
allowed_rdp_cidrs = ["1.2.3.4/32"]

# Multiple IPs
allowed_rdp_cidrs = [
  "1.2.3.4/32",    # Your office
  "5.6.7.8/32"     # Your home
]

# VPN range
allowed_rdp_cidrs = ["10.0.0.0/8"]
```

**WinRM Access (for Ansible):**
```hcl
allowed_winrm_cidrs = ["YOUR-ANSIBLE-HOST-IP/32"]
```

## Outputs

After deployment, Terraform provides:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output dc1_private_ip
terraform output client_private_ips
terraform output rdp_connection_info
terraform output deployment_summary
```

## Ansible Integration

### Auto-Generated Inventory

Terraform automatically generates an Ansible inventory file at:
```
../ansible/inventory/aws_windows.yml
```

### Manual Inventory Path

To change the inventory location:
```hcl
ansible_inventory_path = "/path/to/your/inventory.yml"
```

### Disable Inventory Generation

```hcl
generate_ansible_inventory = false
```

## Running Ansible Playbook

After Terraform deployment:

```bash
# Navigate to your Ansible directory
cd ../ansible

# Verify inventory
ansible-inventory -i inventory/aws_windows.yml --list

# Test connectivity (macOS users need OBJC_ variable)
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/aws_windows.yml -m win_ping

# Run the role-based AD deployment playbook (auto-scales!)
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml

# ⭐ NEW: Role-based playbook automatically handles:
#    - DC1: Creates AD forest
#    - DC2, DC3, DC4...: Join domain + promote (serial execution)
#    - All clients: Join domain
```

**What happens automatically:**
1. Preflight checks on all hosts
2. DC1 creates forest root
3. Additional DCs (DC2, DC3, DC4...) join and promote sequentially
4. All clients join domain
5. Idempotent - safe to re-run!

## Security Groups

### Domain Controllers Security Group

**Inbound Rules:**
- RDP (3389) - from `allowed_rdp_cidrs`
- WinRM HTTP (5985) - from `allowed_winrm_cidrs`
- WinRM HTTPS (5986) - from `allowed_winrm_cidrs`
- LDAP (389) - from VPC
- LDAPS (636) - from VPC
- Global Catalog (3268-3269) - from VPC
- DNS (53 TCP/UDP) - from VPC
- Kerberos (88 TCP/UDP) - from VPC
- Kerberos Password (464) - from VPC
- SMB (445) - from VPC
- NetBIOS (137-139) - from VPC
- DHCP (67) - from VPC
- AD Replication (135, 49152-65535) - from VPC
- ICMP - from VPC

**Outbound Rules:**
- All traffic allowed

### Windows Clients Security Group

**Inbound Rules:**
- RDP (3389) - from `allowed_rdp_cidrs`
- WinRM HTTP (5985) - from `allowed_winrm_cidrs`
- WinRM HTTPS (5986) - from `allowed_winrm_cidrs`
- All traffic - from Domain Controllers SG
- All traffic - from Clients SG (peer communication)
- ICMP - from VPC

**Outbound Rules:**
- All traffic allowed

## Instance User Data

### Domain Controllers
- Sets computer name (DC1, DC2)
- Configures Administrator password
- Enables WinRM for Ansible
- Enables RDP
- Disables IE Enhanced Security
- Creates required directories (`C:\dns-import`, `C:\infoblox`)
- Installs Chocolatey
- Reboots to apply changes

### Clients
- Sets computer name (WIN-CLIENT-1, etc.)
- Configures Administrator password
- Sets DNS to DC1
- Enables WinRM for Ansible
- Enables RDP
- Disables IE Enhanced Security
- Installs Chocolatey
- Reboots to apply changes

## Cost Estimation

**Example monthly costs (eu-central-1, 3 DCs + 2 clients):**
- 3x t3.large (DCs) - $0.17/hr × 3 = $0.51/hr
- 2x t3.medium (Clients) - $0.08/hr × 2 = $0.16/hr
- 5x Elastic IPs - $0.005/hr × 5 = $0.025/hr
- 5x 100GB gp3 EBS volumes - ~$40/month
- **Total: ~$0.70/hr or $504/month** (if left running)

**Cost scales linearly with instance count!**

**Cost optimization:**
- Use smaller instance types for testing (t3.medium for DCs)
- Stop instances when not in use (EIPs still charged)
- Destroy completely when done: `terraform destroy`
- Use t3a instances for 10% savings
- Reduce EBS volume sizes

## Troubleshooting

### Authentication Issues

```bash
# Verify AWS credentials
aws sts get-caller-identity --profile okta-sso

# Re-authenticate with SSO
aws sso login --profile okta-sso

# Check profile configuration
cat ~/.aws/config
```

### Subnet/VPC Issues

```bash
# Verify VPC exists
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx --profile okta-sso

# Verify subnet has available IPs
aws ec2 describe-subnets --subnet-ids subnet-xxxxx --profile okta-sso

# Check if IP is already in use
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=10.100.1.100" \
  --profile okta-sso
```

### Instance Connection Issues

```bash
# Check instance status
aws ec2 describe-instances \
  --instance-ids i-xxxxx \
  --query "Reservations[0].Instances[0].State" \
  --profile okta-sso

# Get instance console output
aws ec2 get-console-output --instance-id i-xxxxx --profile okta-sso

# Use SSM Session Manager (if SSM agent running)
aws ssm start-session --target i-xxxxx --profile okta-sso
```

### WinRM Connection Issues

```bash
# Test WinRM from Ansible host
ansible windows -i inventory/aws_windows.yml -m win_ping -vvv

# Check security group allows WinRM
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --profile okta-sso
```

## Maintenance

### Updating Infrastructure

```bash
# Update variables in terraform.tfvars
vim terraform.tfvars

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Adding More DCs or Clients

```hcl
# In terraform.tfvars
domain_controller_count = 5  # Increase from 3 to 5 (adds DC4, DC5)
client_count            = 8  # Increase from 2 to 8 (adds CLIENT3-8)
```

```bash
# Apply infrastructure changes
terraform apply -auto-approve
sleep 180  # Wait for boot

# Configure new DCs and clients (idempotent - skips existing)
cd ../ansible
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

**What happens:**
- ✅ DC1, DC2, DC3: Skipped (already promoted)
- 🆕 DC4: Joins domain + promotes automatically
- 🆕 DC5: Joins domain + promotes automatically
- 🆕 CLIENT3-8: Join domain automatically

### Scaling Instance Types

```hcl
# In terraform.tfvars
dc_instance_type = "t3.xlarge"  # Upgrade from t3.large
```

```bash
# Note: This requires instance replacement
terraform apply
```

## Cleanup

### Destroy All Resources

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Verify cleanup
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=windows-ad-lab" \
  --profile okta-sso
```

### Partial Cleanup

```bash
# Remove specific client
terraform destroy -target=aws_instance.clients[3]

# Remove all clients
terraform destroy -target=aws_instance.clients
```

## File Structure

```
terraform/
├── main.tf                          # Main infrastructure, data sources
├── providers.tf                     # AWS provider configuration
├── variables.tf                     # Variable definitions
├── terraform.tfvars.example         # Example configuration
├── terraform.tfvars                 # Your configuration (gitignored)
├── ec2.tf                           # EC2 instances (DCs + clients)
├── security-groups.tf               # Security group rules
├── ansible.tf                       # Ansible inventory generation
├── outputs.tf                       # Output values
├── templates/
│   ├── dc_userdata.tpl             # DC bootstrap script
│   ├── client_userdata.tpl         # Client bootstrap script
│   └── ansible_inventory.tpl       # Ansible inventory template
└── README.md                        # This file
```

## Best Practices

1. **Never commit `terraform.tfvars`** - Contains sensitive data
2. **Use AWS Secrets Manager** for production passwords
3. **Enable MFA** on AWS accounts
4. **Use separate AWS accounts** for dev/test/prod
5. **Tag all resources** appropriately
6. **Use state locking** with S3 + DynamoDB backend
7. **Regular backups** of domain controllers
8. **Monitor costs** with AWS Cost Explorer
9. **Use IAM roles** instead of access keys when possible
10. **Enable CloudTrail** for audit logging

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Terraform plan output
3. Check AWS CloudWatch logs
4. Review instance console output
5. Consult AWS documentation

## License

Internal use only - Configure according to your organization's policies.

## Contributors

- Infrastructure automation team
- DevOps team

---

**Last Updated:** 2025-10-15
**Terraform Version:** >= 1.5.0
**AWS Provider Version:** ~> 5.0

## Recent Updates

- **2025-10-15**: Added multi-VPC support with 5 deployment scenarios
- **2025-10-15**: Added comprehensive IP address customization (manual + automatic)
- **2025-10-15**: Fixed single-step terraform apply (no more two-step deployments)
