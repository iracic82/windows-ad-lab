# Multi-VPC Implementation Guide

This guide shows how to deploy Domain Controllers in one VPC and clients in another VPC.

## Use Cases

**Why split across VPCs?**
- DCs in shared services VPC, clients in application VPC
- DCs in production VPC, test clients in dev VPC
- Security isolation between control plane (DCs) and data plane (clients)
- Compliance requirements for network segmentation

## Architecture Example

```
┌─────────────────────────────────────────┐
│ VPC-A (10.10.0.0/16) - DC VPC          │
│                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐         │
│  │ DC1  │  │ DC2  │  │ DC3  │         │
│  │.10.5 │  │.10.6 │  │.10.7 │         │
│  └──────┘  └──────┘  └──────┘         │
│                                         │
└─────────────────────────────────────────┘
                  │
                  │ VPC Peering
                  │
┌─────────────────────────────────────────┐
│ VPC-B (10.20.0.0/16) - Client VPC      │
│                                         │
│  ┌─────────┐  ┌─────────┐             │
│  │ CLIENT1 │  │ CLIENT2 │             │
│  │ .20.10  │  │ .20.11  │             │
│  └─────────┘  └─────────┘             │
│                                         │
└─────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Update Terraform Variables

Add new variables to `terraform/variables.tf`:

```hcl
# Original (keep for backward compatibility)
variable "vpc_id" {
  description = "VPC ID for single-VPC deployment"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "Subnets for single-VPC deployment"
  type        = list(string)
  default     = []
}

# NEW: Multi-VPC support
variable "enable_multi_vpc" {
  description = "Enable multi-VPC deployment (DCs in one VPC, clients in another)"
  type        = bool
  default     = false
}

variable "dc_vpc_id" {
  description = "VPC ID for Domain Controllers"
  type        = string
  default     = ""
}

variable "dc_subnets" {
  description = "Subnets for Domain Controllers"
  type        = list(string)
  default     = []
}

variable "client_vpc_id" {
  description = "VPC ID for Clients"
  type        = string
  default     = ""
}

variable "client_subnets" {
  description = "Subnets for Clients"
  type        = list(string)
  default     = []
}
```

### Step 2: Create VPC Peering Module

Create `terraform/modules/vpc-peering/main.tf`:

```hcl
# terraform/modules/vpc-peering/main.tf

variable "dc_vpc_id" {
  description = "VPC ID containing Domain Controllers"
  type        = string
}

variable "client_vpc_id" {
  description = "VPC ID containing Clients"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "dc_vpc_cidr" {
  description = "CIDR block of DC VPC"
  type        = string
}

variable "client_vpc_cidr" {
  description = "CIDR block of Client VPC"
  type        = string
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "dc_to_client" {
  vpc_id        = var.dc_vpc_id
  peer_vpc_id   = var.client_vpc_id
  auto_accept   = true  # Works if both VPCs in same account

  tags = {
    Name    = "${var.project_name}-dc-client-peering"
    Project = var.project_name
  }
}

# Get route tables for DC VPC
data "aws_route_tables" "dc_vpc" {
  vpc_id = var.dc_vpc_id
}

# Get route tables for Client VPC
data "aws_route_tables" "client_vpc" {
  vpc_id = var.client_vpc_id
}

# Add routes from DC VPC to Client VPC
resource "aws_route" "dc_to_client" {
  for_each = toset(data.aws_route_tables.dc_vpc.ids)

  route_table_id            = each.key
  destination_cidr_block    = var.client_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}

# Add routes from Client VPC to DC VPC
resource "aws_route" "client_to_dc" {
  for_each = toset(data.aws_route_tables.client_vpc.ids)

  route_table_id            = each.key
  destination_cidr_block    = var.dc_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.dc_to_client.id
}
```

### Step 3: Update Main Terraform Configuration

Update `terraform/main.tf`:

```hcl
# Determine VPC configuration based on mode
locals {
  # Single-VPC mode (default)
  dc_vpc_id      = var.enable_multi_vpc ? var.dc_vpc_id : var.vpc_id
  dc_subnets     = var.enable_multi_vpc ? var.dc_subnets : var.subnets
  client_vpc_id  = var.enable_multi_vpc ? var.client_vpc_id : var.vpc_id
  client_subnets = var.enable_multi_vpc ? var.client_subnets : var.subnets
}

# Get DC VPC CIDR
data "aws_vpc" "dc_vpc" {
  id = local.dc_vpc_id
}

# Get Client VPC CIDR
data "aws_vpc" "client_vpc" {
  id = local.client_vpc_id
}

# VPC Peering (only if multi-VPC enabled)
module "vpc_peering" {
  count  = var.enable_multi_vpc ? 1 : 0
  source = "./modules/vpc-peering"

  dc_vpc_id       = local.dc_vpc_id
  client_vpc_id   = local.client_vpc_id
  project_name    = var.project_name
  dc_vpc_cidr     = data.aws_vpc.dc_vpc.cidr_block
  client_vpc_cidr = data.aws_vpc.client_vpc.cidr_block
}

# Update module calls to use correct VPC/subnets
module "domain_controllers" {
  source = "./modules/windows-instance"
  count  = var.domain_controller_count

  name              = "dc${count.index + 1}"
  subnet_id         = element(local.dc_subnets, count.index)
  security_group_id = module.security_groups.dc_sg_id
  vpc_id            = local.dc_vpc_id  # Pass VPC ID to module
  # ... other parameters
}

module "clients" {
  source = "./modules/windows-instance"
  count  = var.client_count

  name              = "client${count.index + 1}"
  subnet_id         = element(local.client_subnets, count.index)
  security_group_id = module.security_groups.client_sg_id
  vpc_id            = local.client_vpc_id  # Pass VPC ID to module
  # ... other parameters
}
```

### Step 4: Update Security Groups

The critical change: **Security groups must allow traffic from remote VPC CIDR blocks**.

Update `terraform/modules/security-groups/main.tf`:

```hcl
variable "dc_vpc_cidr" {
  description = "CIDR block of DC VPC"
  type        = string
}

variable "client_vpc_cidr" {
  description = "CIDR block of Client VPC"
  type        = string
}

# Domain Controllers Security Group
resource "aws_security_group" "domain_controllers" {
  name_prefix = "${var.project_name}-dc-"
  description = "Security group for Domain Controllers"
  vpc_id      = var.dc_vpc_id

  tags = {
    Name = "${var.project_name}-domain-controllers"
  }
}

# CRITICAL: Allow AD traffic from CLIENT VPC CIDR (not just same VPC)
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_tcp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.client_vpc_cidr  # ← Client VPC CIDR
}

resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP from Client VPC"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = var.client_vpc_cidr  # ← Client VPC CIDR
}

# Repeat for all AD ports (DNS, Kerberos, SMB, etc.)
resource "aws_vpc_security_group_ingress_rule" "dc_dns_tcp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.client_vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "dc_dns_udp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "DNS UDP from Client VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.client_vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_tcp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos TCP from Client VPC"
  ip_protocol       = "tcp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.client_vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "dc_kerberos_udp_from_client_vpc" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "Kerberos UDP from Client VPC"
  ip_protocol       = "udp"
  from_port         = 88
  to_port           = 88
  cidr_ipv4         = var.client_vpc_cidr
}

# Add all other AD ports (SMB 445, RPC 135, Global Catalog 3268-3269, etc.)
```

### Step 5: Example terraform.tfvars Configurations

#### Option A: Single VPC (Current, Default)

```hcl
# Single VPC deployment (current behavior)
enable_multi_vpc = false

vpc_id  = "vpc-abc123"
subnets = ["subnet-111", "subnet-222"]

domain_controller_count = 3
client_count            = 2
```

#### Option B: Multi-VPC (DCs and Clients Separated)

```hcl
# Multi-VPC deployment
enable_multi_vpc = true

# Domain Controllers in VPC-A
dc_vpc_id  = "vpc-111111"
dc_subnets = ["subnet-aaa", "subnet-bbb"]

# Clients in VPC-B
client_vpc_id  = "vpc-222222"
client_subnets = ["subnet-xxx", "subnet-yyy"]

domain_controller_count = 3
client_count            = 2
```

#### Option C: Advanced - DCs in Multiple VPCs (Future Enhancement)

This would require even more complex setup:

```hcl
# NOT YET SUPPORTED - Would require per-DC VPC configuration
dc_configurations = [
  { vpc_id = "vpc-111", subnet_id = "subnet-aaa", name = "dc1" },
  { vpc_id = "vpc-222", subnet_id = "subnet-bbb", name = "dc2" },
  { vpc_id = "vpc-333", subnet_id = "subnet-ccc", name = "dc3" }
]
```

This would require full mesh VPC peering between all VPCs.

### Step 6: Ansible - No Changes Needed!

**The great news:** Ansible doesn't care about VPCs! It just uses IP addresses.

The inventory will look the same:

```yaml
all:
  vars:
    dc1_ip: 10.10.10.5   # In VPC-A
    dc2_ip: 10.10.10.6   # In VPC-A

  children:
    domain_controllers:
      hosts:
        dc1: { ansible_host: 3.126.28.111, private_ip: 10.10.10.5 }
        dc2: { ansible_host: 52.29.229.223, private_ip: 10.10.10.6 }

    windows_clients:
      hosts:
        client1: { ansible_host: 18.198.174.18, private_ip: 10.20.1.10 }  # In VPC-B
        client2: { ansible_host: 63.176.72.74, private_ip: 10.20.1.11 }   # In VPC-B
```

Ansible connects via public IPs (or private IPs if you're on VPN), so VPC boundaries don't matter.

### Step 7: Deployment Process

```bash
# 1. Configure multi-VPC in terraform.tfvars
vim terraform/terraform.tfvars

# 2. Deploy infrastructure with VPC peering
cd terraform
terraform init
terraform apply

# 3. Wait for instances to boot
sleep 180

# 4. Run Ansible (same as before!)
cd ../ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

## Testing Multi-VPC Connectivity

After deployment, verify cross-VPC communication:

```bash
# From a client in VPC-B, test connectivity to DC in VPC-A
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Test-NetConnection -ComputerName 10.10.10.5 -Port 389"

# Should show: TcpTestSucceeded : True

# Test DNS resolution
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nslookup corp.infolab 10.10.10.5"

# Should return DC1 records

# Test domain join from client in VPC-B to DC in VPC-A
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nltest /dsgetdc:corp.infolab"

# Should find DC1 successfully
```

## Limitations and Considerations

### Network Performance
- **VPC Peering latency:** Adds ~1-2ms (negligible for AD operations)
- **Same-region peering:** No data transfer charges
- **Cross-region peering:** Incurs data transfer costs

### Security Groups
- **Must explicitly allow cross-VPC traffic** - Can't reference remote security groups
- **Use CIDR blocks** instead of security group IDs for cross-VPC rules
- **More complex to maintain** - Changes to VPC CIDR require security group updates

### DNS Considerations
- Clients in VPC-B must use **private IPs** of DCs in VPC-A (10.10.10.5)
- Can't use VPC DNS hostnames across VPC boundaries
- Our Ansible roles already handle this correctly

### VPC Peering Limits
- **Maximum 125 VPC peering connections per VPC**
- **No transitive peering** - If VPC-A peers with VPC-B, and VPC-B peers with VPC-C, VPC-A can't talk to VPC-C
- **Full mesh required** for multiple DC VPCs

### Terraform State Management
- More complex state with peering connections
- Destroying VPCs requires destroying peering first
- `terraform destroy` handles this automatically

## Cost Impact

**VPC Peering costs:**
- ✅ **FREE** for same-region peering
- ✅ **No hourly charges**
- ❌ **Data transfer charges** for cross-region ($0.01-0.02/GB)

**AD traffic estimates:**
- Typical AD replication: 1-10 GB/month
- Client authentication: Minimal (<100 MB/day)
- **Total additional cost:** ~$0-1/month for same-region

## Implementation Effort

**Estimated time:**
- Terraform module creation: 2 hours
- Security group updates: 1 hour
- Testing and validation: 1 hour
- Documentation: 30 minutes
- **Total: ~4-5 hours**

## Real-World Example

```
Production Environment:
└── us-east-1
    ├── VPC-CORP (10.10.0.0/16) - Shared Services
    │   ├── DC1 (10.10.10.5)
    │   ├── DC2 (10.10.10.6)
    │   └── DC3 (10.10.10.7)
    │
    ├── VPC-APP-PROD (10.20.0.0/16) - Production Apps
    │   ├── APP-SERVER-1 (10.20.1.10) ← domain-joined to VPC-CORP DCs
    │   ├── APP-SERVER-2 (10.20.1.11) ← domain-joined to VPC-CORP DCs
    │   └── APP-SERVER-3 (10.20.1.12) ← domain-joined to VPC-CORP DCs
    │
    └── VPC-APP-DEV (10.30.0.0/16) - Development
        ├── DEV-SERVER-1 (10.30.1.10) ← domain-joined to VPC-CORP DCs
        └── DEV-SERVER-2 (10.30.1.11) ← domain-joined to VPC-CORP DCs

Peering Connections:
- VPC-CORP ←→ VPC-APP-PROD
- VPC-CORP ←→ VPC-APP-DEV
```

## Alternative: AWS Transit Gateway

For **3+ VPCs**, consider **AWS Transit Gateway** instead of VPC peering:

```hcl
# Simplified routing with Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description = "Transit Gateway for AD multi-VPC"
}

# Attach all VPCs to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "dc_vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.dc_vpc_id
  subnet_ids         = var.dc_subnets
}

resource "aws_ec2_transit_gateway_vpc_attachment" "client_vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.client_vpc_id
  subnet_ids         = var.client_subnets
}
```

**Transit Gateway benefits:**
- Hub-and-spoke topology (simpler than full mesh peering)
- Transitive routing (VPC-A can reach VPC-C through VPC-B)
- Easier to scale beyond 3 VPCs

**Transit Gateway costs:**
- $0.05/hour per attachment (~$36/month per VPC)
- $0.02/GB data transfer

## Next Steps

**Want me to implement this?** I can:

1. ✅ Create the VPC peering module
2. ✅ Update security groups for cross-VPC traffic
3. ✅ Add multi-VPC variables to Terraform
4. ✅ Update documentation
5. ✅ Create example configurations
6. ✅ Test with 2 VPCs (DC VPC + Client VPC)

Let me know if you want to proceed with the implementation!
