# Windows Active Directory Lab - Multi-Cloud Deployment

**Automated deployment of multi-DC Active Directory forest on AWS and Azure** using Terraform + Ansible with **role-based architecture** that scales automatically.

## Documentation Hub

### Getting Started
| Document | Description |
|----------|-------------|
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | Complete setup guide for new users |
| [PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md) | AWS vs Azure comparison and platform selection |

### Platform-Specific Deployment Guides
| Platform | Status | Guide | Description |
|----------|--------|-------|-------------|
| **AWS** | Production Ready | This README | Deploy to existing or new VPCs with multi-VPC support |
| **Azure** | Production Ready | [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) | Deploy with VNet peering |

### Technical Documentation
| Document | Description |
|----------|-------------|
| [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) | Implementation details, critical fixes |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions for AWS/Azure |
| [terraform/README.md](terraform/README.md) | Terraform workspace structure and module documentation |

---

## Cloud Platform Support

### AWS Deployment
- **Best for:** Organizations with existing AWS infrastructure
- **Network:** Single VPC or multi-VPC with peering
- **Cost:** ~$500/month (2 DCs + 2 clients)
- **Guide:** This README (sections below)

### Azure Deployment
- **Best for:** Lower costs, native Microsoft integration
- **Network:** Separate VNets with automatic peering
- **Cost:** ~$295/month (2 DCs + 2 clients)
- **Guide:** [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)

### Key Differences
| Feature | AWS | Azure |
|---------|-----|-------|
| **Networking** | VPC (manual peering) | VNet (auto peering) |
| **Default Setup** | Same VPC for DCs and clients | Separate VNets |
| **Configuration File** | `terraform.tfvars` | `terraform.tfvars.azure` |
| **Inventory File** | `aws_windows.yml` | `azure_windows.yml` |
| **Ansible Playbooks** | ✅ Same playbooks work for both platforms | ✅ Same playbooks work for both platforms |

---

# AWS Deployment Guide

This section covers deploying to **AWS**. For Azure, see [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md).

## What This Deploys

- **N Domain Controllers** (1-100+) with automatic scaling
- **M Windows Clients** (0-100+) with automatic scaling
- AD-integrated DNS with forwarders
- DHCP server on DC1
- Global Catalog servers
- Domain: `corp.infolab`

Successfully tested with 3 DCs and 2 clients with zero deployment failures.

---

## Architecture

### Role-Based Ansible
```
ansible/roles/
├── ad_common/           # Preflight, ADDS install (all hosts)
├── ad_first_dc/         # Forest creation (DC1 only)
├── ad_additional_dc/    # Domain join + promote (DC2, DC3, DC4...)
└── ad_client/           # Client domain join (all clients)

playbooks/site.yml       # Orchestrator - scales automatically!
```

**Architecture Design:**
- `domain_controllers[0]` creates the AD forest
- `domain_controllers[1:]` join domain and promote to DCs
- `windows_clients` join the domain as member servers

Modifying counts in `terraform.tfvars` automatically scales both infrastructure and configuration.

### Modular Terraform
```
terraform/
├── aws/                      # AWS workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── modules -> ../modules   # Symlink to shared modules
│
├── azure/                    # Azure workspace
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.azure
│   └── modules -> ../modules   # Symlink to shared modules
│
└── modules/                  # Shared modules (via symlinks)
    ├── windows-instance/         # AWS EC2 instances
    ├── security-groups/          # AWS security groups
    ├── iam/                      # AWS IAM roles
    ├── azure-networking/         # Azure VNets + NSGs
    ├── azure-windows-vm/         # Azure VMs
    └── ansible-inventory/        # Cross-platform inventory generation
```

**Design Approach:** Separate workspaces share common modules via symlinks, enabling independent state files while reusing code.

---

## Quick Start - AWS

**Note:** This is the AWS deployment guide. For Azure, see [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md).

### Prerequisites
```bash
# Required tools
aws --version           # AWS CLI configured
terraform --version     # >= 1.0
ansible --version       # >= 2.12
python3 -m pip install pywinrm

# Ansible collections (same for both AWS and Azure)
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad
```

**Complete setup instructions:** See [GETTING_STARTED.md](GETTING_STARTED.md) for detailed installation steps.

### 1. Deploy Infrastructure to AWS (5-10 min)

```bash
# Navigate to AWS terraform workspace
cd terraform/aws

# Edit AWS configuration
vim terraform.tfvars

# Scale here!
domain_controller_count = 3  # ← Change to 5, 10, etc.
client_count            = 2  # ← Change to 0, 5, 10, etc.

# Required AWS variables:
# - aws_region
# - aws_profile
# - vpc_id
# - subnets
# - key_name
# - allowed_rdp_cidrs
# - allowed_winrm_cidrs

# Deploy to AWS
terraform init
terraform apply -auto-approve

# Wait for VMs to boot
sleep 180
```

### 2. Configure AD (30-45 min)

```bash
cd ../ansible

# Test connectivity
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/aws_windows.yml -m win_ping

# Deploy AD (idempotent - safe to re-run)
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

### 3. Verify

```bash
# Check domain membership
ansible windows -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# All should return: corp.infolab
```

**RDP Access:**
```bash
terraform output rdp_connection_info
# Use Administrator / P@ssw0rd123!SecureAD
```

---

## AWS Multi-VPC Deployment

The AWS deployment supports flexible VPC configurations allowing you to mix and match existing and new VPCs for Domain Controllers and Clients.

### Supported Scenarios

| Scenario | DCs | Clients | VPC Peering | Use Case |
|----------|-----|---------|-------------|----------|
| **1. Same Existing VPC** | Existing VPC | Same VPC | Not needed | Default, backward compatible |
| **2. Separate Existing VPCs** | Existing VPC | Different existing VPC | Auto-created | Integrate with existing infrastructure |
| **3. Create Both New VPCs** | New VPC | New VPC | Auto-created | Greenfield deployment |
| **4. Mix: Existing DC + New Client** | Existing VPC | New VPC | Auto-created | Recommended for security segmentation |
| **5. Mix: New DC + Existing Client** | New VPC | Existing VPC | Auto-created | Reverse of scenario 4 |

### Quick Configuration Guide

Edit `terraform/aws/terraform.tfvars`:

**Scenario 1: Same Existing VPC (Default)**
```hcl
use_existing_vpcs = true
use_separate_vpcs = false
vpc_id  = "vpc-xxxxx"
subnets = ["subnet-xxxxx", "subnet-yyyyy"]
```

**Scenario 4: Existing DC VPC + New Client VPC (Recommended)**
```hcl
use_existing_vpcs = false  # We're creating Client VPC
use_separate_vpcs = true
create_dc_vpc     = false  # Use existing DC VPC
create_client_vpc = true   # Create new Client VPC

# Existing DC infrastructure
existing_dc_vpc_id  = "vpc-0a7299af0067aff53"
existing_dc_subnets = ["subnet-xxxxx", "subnet-yyyyy"]

# New Client VPC (Terraform creates this)
client_vpc_cidr    = "10.11.0.0/16"
client_subnet_cidr = "10.11.11.0/24"
```

**Scenario 3: Create Both New VPCs**
```hcl
use_existing_vpcs = false
use_separate_vpcs = true
create_dc_vpc     = true
create_client_vpc = true

dc_vpc_cidr        = "10.10.0.0/16"
dc_subnet_cidr     = "10.10.10.0/24"
client_vpc_cidr    = "10.11.0.0/16"
client_subnet_cidr = "10.11.11.0/24"
```

### What Happens Automatically

When using separate VPCs, Terraform automatically:
- Creates VPC peering connection when VPCs differ
- Updates all route tables in both VPCs
- Configures security groups for cross-VPC AD traffic
- Enables all AD ports: LDAP, Kerberos, DNS, SMB, RPC
- Sets up bidirectional communication

No manual networking configuration required.

### IP Address Customization

The AWS deployment supports both manual and automatic IP address assignment for Domain Controllers and Clients.

#### Option 1: Manual IP Assignment (Recommended for Production)

Specify exact IP addresses for each instance:

```hcl
# Custom IP addresses
dc_private_ips     = ["10.10.10.10", "10.10.10.71"]
client_private_ips = ["10.11.11.5", "10.11.11.6"]
```

**Important:** Ensure IPs fall within your subnet CIDR ranges and avoid network/broadcast addresses.

#### Option 2: Automatic IP Assignment

Let Terraform calculate IPs using configurable offsets:

```hcl
# Leave arrays empty for auto-calculation
dc_private_ips     = []
client_private_ips = []

# Configure starting offsets
dc_ip_start_offset     = 10  # DCs get .10, .11, .12...
client_ip_start_offset = 20  # Clients get .20, .21, .22...
```

#### IP Assignment Logic

- **Same VPC mode:** Clients start after last DC IP to avoid conflicts
- **Separate VPC mode:** Each VPC uses its own offset independently
- **Multi-subnet:** IPs distributed round-robin across subnets
- **Validation:** Terraform validates IPs against subnet ranges before deployment

#### Example: Multi-VPC with Custom IPs

```hcl
# Existing DC VPC + New Client VPC
use_existing_vpcs = false
use_separate_vpcs = true
create_dc_vpc     = false
create_client_vpc = true

existing_dc_vpc_id  = "vpc-0a7299af0067aff53"
existing_dc_subnets = [
  "subnet-0a9f063607662c0f0",  # 10.10.10.0/28
  "subnet-0d0044ce1fabf4833"   # 10.10.10.64/28
]

client_vpc_cidr    = "10.11.0.0/16"
client_subnet_cidr = "10.11.11.0/24"

# Custom IPs matching subnet ranges
dc_private_ips     = ["10.10.10.10", "10.10.10.71"]  # Within /28 subnets
client_private_ips = ["10.11.11.5", "10.11.11.6"]    # Within /24 subnet

domain_controller_count = 2
client_count            = 2
```

### Complete Configuration Examples

See `terraform/aws/terraform.tfvars.example` for all 5 scenarios with detailed comments and IP customization examples.

---

## Scaling Operations

### Add 2 More DCs (Scale from 3 to 5)

```bash
# 1. Edit terraform.tfvars
domain_controller_count = 5  # Was 3

# 2. Apply changes
cd terraform
terraform apply -auto-approve
sleep 180

# 3. Run Ansible (automatically handles DC4, DC5)
cd ../ansible
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

**Deployment process:**
- DC1: Skipped, already forest root
- DC2, DC3: Skipped, already promoted
- DC4: Joins domain and promotes automatically
- DC5: Joins domain and promotes automatically

### Add Clients

```bash
client_count = 5  # Add CLIENT3, CLIENT4, CLIENT5
terraform apply -auto-approve
sleep 180
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

---

## AWS Configuration

### AWS terraform.tfvars

**Location:** `terraform/aws/terraform.tfvars`

```hcl
# ===================================
# AWS Configuration
# ===================================
aws_region  = "eu-central-1"  # Your AWS region
aws_profile = "okta-sso"      # Your AWS CLI profile

# ===================================
# Network Configuration
# ===================================
vpc_id  = "vpc-xxxxx"          # Your existing VPC
subnets = ["subnet-xxxxx"]     # One or more subnets

# ===================================
# Scale Configuration
# ===================================
domain_controller_count = 3    # Number of DCs (1-100+)
client_count            = 2    # Number of clients (0-100+)

# ===================================
# Domain Configuration
# ===================================
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"  # Change this!

# ===================================
# Instance Configuration
# ===================================
dc_instance_type     = "t3.large"   # DCs: 2 vCPU, 8GB
client_instance_type = "t3.medium"  # Clients: 2 vCPU, 4GB

# ===================================
# Security Configuration
# ===================================
key_name            = "your-key-name"
allowed_rdp_cidrs   = ["YOUR.IP.HERE/32"]
allowed_winrm_cidrs = ["YOUR.IP.HERE/32"]
```

**For Azure configuration**, see [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) - uses `terraform/azure/terraform.tfvars.azure`

---

## Troubleshooting

### 1. Domain Join Fails: "Domain does not exist"

**Root Cause:** AMI has static DNS `10.10.10.10` pre-configured.

**Fix (already in roles):**
```powershell
Get-NetAdapter | Where-Object Status -eq Up |
  Set-DnsClientServerAddress -ServerAddresses 10.10.10.5
```

Location: `roles/ad_additional_dc/tasks/main.yml:30-38`

### 2. "InstallDNS parameter not recognized"

**Root Cause:** Windows Server 2025 removed `install_dns` parameter.

**Fix (already applied):** Removed from all promotion tasks.

### 3. Playbook Times Out

**Usually DC completed anyway!** Verify:
```bash
ansible dc3 -i inventory/aws_windows.yml -m ansible.windows.win_shell \
  -a "Get-ADDomainController -Server localhost"
```

If verified, just re-run (idempotent):
```bash
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

---

## Project Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── windows-instance/
│   │   ├── security-groups/
│   │   ├── iam/
│   │   └── ansible-inventory/
│   ├── templates/
│   │   ├── dc_userdata.tpl
│   │   └── client_userdata.tpl
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars    # ← EDIT THIS
│
├── ansible/
│   ├── roles/
│   │   ├── ad_common/
│   │   ├── ad_first_dc/
│   │   ├── ad_additional_dc/  # ← DNS fix here
│   │   └── ad_client/         # ← DNS fix here
│   ├── playbooks/
│   │   └── site.yml          # ← RUN THIS
│   ├── inventory/
│   │   └── aws_windows.yml   # Auto-generated
│   └── ansible.cfg
│
└── README.md                 # This file
```

---

## Cost Considerations

**AWS Pricing (eu-central-1):**
- **3 DCs (t3.large):** $0.17/hr × 3 = $0.51/hr
- **2 Clients (t3.medium):** $0.08/hr × 2 = $0.16/hr
- **5 EIPs:** $0.005/hr × 5 = $0.025/hr
- **Total:** ~$0.70/hr or **$504/month** (if left running)

**Save Money:**
```bash
# Stop when not in use
terraform apply -var="instance_state=stopped"

# Or destroy completely
terraform destroy -auto-approve
```

---

## Success Criteria

Deployment successful when:
- Terraform apply completes with 0 errors
- Ansible playbook completes with 0 failures
- All systems joined to `corp.infolab` domain
- `nltest /dsgetdc:corp.infolab` works from all hosts
- RDP access works with domain credentials

---

## Security Notes

**Current Configuration (Lab Environment):**
- Windows Firewall disabled for simplicity
- Static password in code
- HTTP WinRM instead of HTTPS

**Production Recommendations:**
1. Use AWS Secrets Manager for passwords
2. Enable Windows Firewall with AD rules
3. Configure HTTPS for WinRM
4. Use AWS Directory Service for managed AD
5. Enable CloudWatch Logs
6. Remove public EIPs, use VPN/Direct Connect

---

## Tested Configurations

| DCs | Clients | Result  | Duration |
|-----|---------|---------|----------|
| 2   | 1       | Success | 25 min   |
| 3   | 2       | Success | 35 min   |

---

## Complete Documentation Index

### Getting Started
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup guide for new users
- **[PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md)** - AWS vs Azure comparison

### Deployment Guides
- **This README** - AWS deployment guide
- **[AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)** - Azure deployment guide with VNet options

### Technical Resources
- **[TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)** - Implementation details, fixes, troubleshooting
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[terraform/README.md](terraform/README.md)** - Terraform structure and workspaces

---

## Azure Deployment

This README covers AWS deployment. For Azure deployment:

See [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) for complete Azure guide

**Key Azure differences:**
- Uses `terraform/azure/` workspace with separate state
- Configuration in `terraform.tfvars.azure`
- Separate VNets for DCs and clients with automatic peering
- Lower cost (~$295/month vs ~$500/month for AWS)
- Inventory file: `ansible/inventory/azure_windows.yml`
- Same Ansible playbooks work for both platforms

---

## Contributing

Contributions are welcome:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with tests

---

## License

MIT License

---

## Acknowledgments

- Built on Terraform AWS and Azure providers
- Uses Ansible Windows and Microsoft AD collections
- Proven at scale with role-based architecture
- Multi-cloud support with shared modules

---

**Support:** For issues or questions, refer to [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or open a GitHub issue.

**Repository:** https://github.com/iracic82/windows-ad-lab
