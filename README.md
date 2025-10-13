# Windows Active Directory Lab - Scalable Deployment

**Automated deployment of multi-DC Active Directory forest on AWS** using Terraform + Ansible with **role-based architecture** that scales automatically.

## 🎯 What This Deploys

- **N Domain Controllers** (1-100+) - automatically scales
- **M Windows Clients** (0-100+) - automatically scales
- AD-integrated DNS with forwarders
- DHCP server on DC1
- Global Catalog servers
- Domain: `corp.infolab`

**Proven at scale:** ✅ 3 DCs + 2 clients deployed successfully (zero failures)

---

## 🏗️ Architecture

### Role-Based Ansible (NEW!)
```
ansible/roles/
├── ad_common/           # Preflight, ADDS install (all hosts)
├── ad_first_dc/         # Forest creation (DC1 only)
├── ad_additional_dc/    # Domain join + promote (DC2, DC3, DC4...)
└── ad_client/           # Client domain join (all clients)

playbooks/site.yml       # Orchestrator - scales automatically!
```

**Key Innovation:**
- `domain_controllers[0]` → First DC creates forest
- `domain_controllers[1:]` → Additional DCs join + promote
- `windows_clients` → All clients join

**Result:** Change counts in `terraform.tfvars` → infrastructure + Ansible scales automatically!

### Modular Terraform
```
terraform/modules/
├── windows-instance/    # Reusable EC2 module
├── security-groups/     # AD-specific rules
├── iam/                 # SSM policies
└── ansible-inventory/   # Auto-generates inventory
```

---

## 🚀 Quick Start

### Prerequisites
```bash
# Required
aws --version           # AWS CLI with SSO
terraform --version     # >= 1.0
ansible --version       # >= 2.12
python3 -m pip install pywinrm

# Ansible collections
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad
```

### 1. Deploy Infrastructure (5 min)

```bash
cd terraform

# Edit terraform.tfvars
vim terraform.tfvars

# Scale here!
domain_controller_count = 3  # ← Change to 5, 10, etc.
client_count            = 2  # ← Change to 0, 5, 10, etc.

# Deploy
terraform init
terraform apply -auto-approve

# Wait for boot
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

## 📈 Scaling Made Easy

### Add 2 More DCs (Scale 3→5)

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

**What happens:**
- ✅ DC1: Skipped (already forest root)
- ✅ DC2, DC3: Skipped (already promoted)
- 🆕 DC4: Joins + promotes automatically
- 🆕 DC5: Joins + promotes automatically

### Add Clients

```bash
client_count = 5  # Add CLIENT3, CLIENT4, CLIENT5
terraform apply -auto-approve
sleep 180
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

---

## 🛠️ Configuration

### terraform.tfvars

```hcl
# AWS
aws_region  = "eu-central-1"
aws_profile = "okta-sso"

# Network
vpc_id = "vpc-xxxxx"
subnets = ["subnet-xxxxx"]  # Single subnet OK

# Scale!
domain_controller_count = 3  # 1-100+
client_count            = 2  # 0-100+

# Domain
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"

# Instances
dc_instance_type     = "t3.large"   # 2 vCPU, 8GB
client_instance_type = "t3.medium"  # 2 vCPU, 4GB

# Security
key_name            = "infoblox-tme"
allowed_rdp_cidrs   = ["YOUR.IP/32"]
allowed_winrm_cidrs = ["YOUR.IP/32"]
```

---

## 🐛 Troubleshooting

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

## 🌐 Multi-VPC Setup

### Complexity Levels

| Setup | Difficulty | Requirements |
|-------|-----------|--------------|
| **Single VPC** | Easy | Current setup ✅ |
| **DCs in VPC-A, Clients in VPC-B** | Medium | VPC peering + routes |
| **Multi-region DCs** | Hard | VPN/Direct Connect |

### Multi-VPC Architecture (DCs + Clients in Different VPCs)

**Is it hard?** **No** - just needs VPC peering.

#### What You Need:

1. **VPC Peering** between DC VPC and Client VPC
2. **Route tables** updated on both sides
3. **Security groups** allowing cross-VPC AD traffic

#### Terraform Changes Required:

```hcl
# terraform/modules/vpc-peering/main.tf (NEW MODULE)
resource "aws_vpc_peering_connection" "dc_to_client" {
  vpc_id        = var.dc_vpc_id
  peer_vpc_id   = var.client_vpc_id
  auto_accept   = true

  tags = {
    Name = "${var.project_name}-dc-client-peering"
  }
}

# Add routes
resource "aws_route" "dc_to_client" {
  route_table_id            = data.aws_route_table.dc_vpc.id
  destination_cidr_block    = data.aws_vpc.client.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}

resource "aws_route" "client_to_dc" {
  route_table_id            = data.aws_route_table.client_vpc.id
  destination_cidr_block    = data.aws_vpc.dc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}
```

#### terraform.tfvars Changes:

```hcl
# DCs in VPC-A
dc_vpc_id     = "vpc-111111"
dc_subnets    = ["subnet-aaa"]

# Clients in VPC-B
client_vpc_id     = "vpc-222222"
client_subnets    = ["subnet-bbb"]

# Enable peering
create_vpc_peering = true
```

#### Security Group Changes:

```hcl
# Allow AD traffic from CLIENT VPC CIDR (not just same VPC)
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.client.cidr_block  # ← Client VPC CIDR
}
```

**Ansible:** No changes needed. The playbook uses IPs from inventory regardless of VPC topology.

#### Implementation Effort:

- **Terraform refactor:** 2-3 hours (create vpc-peering module, update main.tf)
- **Testing:** 1 hour
- **Total:** Approximately half day

#### Real-World Use Case:

```
VPC-A (10.10.0.0/16) - Production DCs
├── DC1 (10.10.10.5)
├── DC2 (10.10.10.6)
└── DC3 (10.10.10.7)

        ↕ VPC Peering

VPC-B (10.20.0.0/16) - Application Servers
├── APP-SERVER-1 (10.20.1.10) ← domain-joined
├── APP-SERVER-2 (10.20.1.11) ← domain-joined
└── APP-SERVER-3 (10.20.1.12) ← domain-joined
```

**Note:** Multi-VPC support can be implemented by adding the vpc-peering module and updating security group rules to use CIDR blocks. See `docs/MULTI_VPC_IMPLEMENTATION.md` and `docs/MULTI_VPC_EXISTING_PEERING.md` for detailed implementation guides.

---

## 📂 Project Structure

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

## 💰 Costs

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

## ✅ Success Criteria

Deployment successful when:
- ✅ Terraform apply: 0 errors
- ✅ Ansible playbook: 0 failures
- ✅ All systems in `corp.infolab` domain
- ✅ `nltest /dsgetdc:corp.infolab` works from all hosts
- ✅ Can RDP with domain credentials

---

## 🔐 Security Notes

**Current (Lab Setup):**
- ⚠️ Windows Firewall disabled (for simplicity)
- ⚠️ Static password in code
- ⚠️ HTTP WinRM (not HTTPS)

**For Production:**
1. Use AWS Secrets Manager for passwords
2. Enable Windows Firewall with AD rules
3. Configure HTTPS for WinRM
4. Use AWS Directory Service for managed AD
5. Enable CloudWatch Logs
6. Remove public EIPs, use VPN/Direct Connect

---

## 🧪 Tested Configurations

| DCs | Clients | Result | Duration |
|-----|---------|--------|----------|
| 2   | 1       | ✅ Success | 25 min |
| 3   | 2       | ✅ Success | 35 min |

---

## 📚 Documentation

- **Quick Start:** This README
- **Scaling Guide:** See "Scaling Made Easy" section above
- **Multi-VPC:** See "Multi-VPC Setup" section above
- **Troubleshooting:** See "Troubleshooting" section above

---

## 🤝 Contributing

**Contributions are welcome:**
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with tests

---

## 📄 License

MIT License

---

## 🙏 Acknowledgments

- Built on Terraform AWS Provider
- Uses Ansible Windows & Microsoft AD collections
- Proven at scale with role-based architecture

---

**Support:** For issues or questions, refer to the troubleshooting section or open a GitHub issue.

**Repository:** https://github.com/iracic82/windows-ad-lab
