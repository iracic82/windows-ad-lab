# Multi-VPC Deployment with Existing VPC Peering

This guide covers deploying Domain Controllers and clients in separate VPCs when VPC peering has already been configured by the network team.

**Prerequisites:**
- VPC peering already configured between target VPCs
- Route tables already updated for cross-VPC communication
- Security groups allow cross-VPC traffic (or will be created)

---

## Current Limitation

The Terraform code currently supports only a single VPC for all resources:

```hcl
# Everything must be in one VPC
vpc_id  = "vpc-abc123"
subnets = ["subnet-111", "subnet-222"]

domain_controller_count = 3
client_count            = 2
```

## Target Architecture

Desired configuration: Domain Controllers in one VPC, clients in another VPC.

```
VPC-A (10.10.0.0/16) - Domain Controllers
├── DC1 (10.10.10.5)
├── DC2 (10.10.10.6)
└── DC3 (10.10.10.7)
         │
         │ VPC Peering (already configured)
         │
VPC-B (10.20.0.0/16) - Clients
├── CLIENT1 (10.20.1.10)
└── CLIENT2 (10.20.1.11)
```

---

## Available Solutions

### Solution 1: Separate Terraform Deployments

Deploy resources in two separate runs using different variable files.

**Step 1: Deploy Domain Controllers**

Create `terraform-dcs.tfvars`:
```hcl
vpc_id  = "vpc-AAAA-for-DCs"
subnets = ["subnet-dc-1", "subnet-dc-2"]

domain_controller_count = 3
client_count            = 0  # No clients
```

Deploy:
```bash
cd terraform
terraform apply -var-file="terraform-dcs.tfvars"
```

**Step 2: Deploy Clients**

Create `terraform-clients.tfvars`:
```hcl
vpc_id  = "vpc-BBBB-for-clients"
subnets = ["subnet-client-1", "subnet-client-2"]

domain_controller_count = 0  # No DCs
client_count            = 2
```

Deploy:
```bash
terraform apply -var-file="terraform-clients.tfvars"
```

**Limitations:**
- Creates separate Terraform states
- Requires manual inventory merging
- More complex to manage

---

### Solution 2: Enhanced Variable Structure

A more flexible approach would modify the Terraform variable structure to support per-instance VPC configuration:

```hcl
# Proposed configuration (requires code changes)
domain_controllers = [
  { vpc_id = "vpc-AAAA", subnet_id = "subnet-dc-1" },
  { vpc_id = "vpc-AAAA", subnet_id = "subnet-dc-2" },
  { vpc_id = "vpc-AAAA", subnet_id = "subnet-dc-3" }
]

clients = [
  { vpc_id = "vpc-BBBB", subnet_id = "subnet-client-1" },
  { vpc_id = "vpc-BBBB", subnet_id = "subnet-client-2" }
]
```

**Implementation:**
- Requires modifying Terraform module calls
- Add logic to handle per-resource VPC selection
- Update security group rules for cross-VPC communication

---

### Solution 3: Simplified Multi-VPC Variables

Add dedicated VPC variables for DCs and clients while maintaining the current architecture.

**New variables in `terraform.tfvars`:**

```hcl
# Domain Controllers VPC
dc_vpc_id      = "vpc-AAAA-for-DCs"
dc_subnets     = ["subnet-dc-1", "subnet-dc-2"]
domain_controller_count = 3

# Clients VPC
client_vpc_id  = "vpc-BBBB-for-clients"
client_subnets = ["subnet-client-1", "subnet-client-2"]
client_count   = 2

# Network assumptions:
# - VPC peering between dc_vpc_id and client_vpc_id exists
# - Routes configured in both VPC route tables
# - Cross-VPC traffic allowed (or will be configured)
```

**Terraform behavior:**
- Deploy DCs in `dc_vpc_id` using `dc_subnets`
- Deploy clients in `client_vpc_id` using `client_subnets`
- Create security groups allowing cross-VPC traffic via CIDR blocks
- Does NOT create or modify VPC peering
- Does NOT modify route tables

**Required Terraform changes:**
1. Add new variables to `variables.tf`
2. Update module calls to use VPC-specific variables
3. Modify security groups to allow cross-VPC CIDR blocks
4. Update inventory generator to handle cross-VPC hosts

---

## Required Information

Before deployment, gather the following from the network team:

### VPC Information

```bash
# Domain Controllers VPC
DC_VPC_ID="vpc-0abc123def456"
DC_VPC_CIDR="10.10.0.0/16"
DC_SUBNET_1="subnet-aaa111"
DC_SUBNET_2="subnet-aaa222"

# Clients VPC
CLIENT_VPC_ID="vpc-0xyz789ghi012"
CLIENT_VPC_CIDR="10.20.0.0/16"
CLIENT_SUBNET_1="subnet-bbb111"
CLIENT_SUBNET_2="subnet-bbb222"

# VPC Peering
PEERING_ID="pcx-0abcdef123"  # Status should be "active"
```

### Verification Commands

```bash
# Verify VPC peering exists and is active
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[*].[VpcPeeringConnectionId,RequesterVpcInfo.VpcId,AccepterVpcInfo.VpcId]' \
  --output table

# Check routes in DC VPC
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$DC_VPC_ID" \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'

# Check routes in Client VPC
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$CLIENT_VPC_ID" \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'
```

**Expected result:** Routes to remote VPC CIDR via peering connection ID.

---

## Example Configuration

### Single VPC (Current, Default)

```hcl
# terraform.tfvars
vpc_id  = "vpc-abc123"
subnets = ["subnet-111", "subnet-222"]

domain_controller_count = 3
client_count            = 2
```

### Multi-VPC (Future Enhancement)

```hcl
# terraform.tfvars
# Domain Controllers in shared services VPC
dc_vpc_id  = "vpc-0abc123def456"
dc_subnets = ["subnet-dc1", "subnet-dc2"]
domain_controller_count = 3

# Clients in application VPC
client_vpc_id  = "vpc-0xyz789ghi012"
client_subnets = ["subnet-client1", "subnet-client2"]
client_count = 2

# Domain configuration
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"

# Instance configuration
dc_instance_type     = "t3.large"
client_instance_type = "t3.medium"

# Security
key_name            = "your-key-name"
allowed_rdp_cidrs   = ["YOUR.IP/32"]
allowed_winrm_cidrs = ["YOUR.IP/32"]
```

---

## Security Group Configuration

When deploying across VPCs, security groups must allow traffic using CIDR blocks instead of security group references.

**DC Security Group (in DC VPC):**
```hcl
# Allow LDAP from Client VPC CIDR
ingress {
  from_port   = 389
  to_port     = 389
  protocol    = "tcp"
  cidr_blocks = ["10.20.0.0/16"]  # Client VPC CIDR
}

# Repeat for all AD ports: DNS (53), Kerberos (88), SMB (445), etc.
```

**Client Security Group (in Client VPC):**
```hcl
# Allow responses from DC VPC
ingress {
  from_port   = 0
  to_port     = 65535
  protocol    = "-1"
  cidr_blocks = ["10.10.0.0/16"]  # DC VPC CIDR
}
```

---

## Ansible Considerations

Ansible operates independently of VPC boundaries and requires no changes for multi-VPC deployments.

**Inventory structure remains the same:**
```yaml
all:
  vars:
    dc1_ip: 10.10.10.5   # In VPC-A

  children:
    domain_controllers:
      hosts:
        dc1: { ansible_host: 3.126.28.111, private_ip: 10.10.10.5 }

    windows_clients:
      hosts:
        client1: { ansible_host: 18.198.174.18, private_ip: 10.20.1.10 }  # In VPC-B
```

Ansible uses either public IPs or private IPs (if running from within AWS) and is unaffected by VPC boundaries.

---

## Verification Steps

After deployment, verify cross-VPC connectivity:

```bash
# Test network connectivity from client to DC
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Test-NetConnection -ComputerName {{ dc1_ip }} -Port 389"

# Expected: TcpTestSucceeded : True

# Verify DNS resolution
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nslookup corp.infolab {{ dc1_ip }}"

# Expected: Returns DC records

# Verify domain join
ansible windows -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# Expected: corp.infolab (all hosts)
```

---

## Common Issues

### Issue: No Route to DC

**Symptom:** `Test-NetConnection` fails from client to DC

**Resolution:**
1. Verify VPC peering is active
2. Check route tables contain peering routes
3. Confirm security groups allow required ports

### Issue: Domain Join Fails

**Error:** "The specified domain either does not exist or could not be contacted"

**Resolution:**
1. Verify security groups allow LDAP UDP port 389
2. Check DNS is set to DC IP on clients
3. Confirm cross-VPC routes exist

### Issue: Overlapping CIDR Blocks

**Error:** VPC CIDRs overlap

**Resolution:** VPCs must have non-overlapping CIDR blocks. Modify one VPC's CIDR or select different VPCs.

---

## Implementation Roadmap

**Phase 1: Current State**
- Single VPC deployment
- All resources in same VPC
- Working and tested

**Phase 2: Add Multi-VPC Variables**
- Add `dc_vpc_id`, `dc_subnets`
- Add `client_vpc_id`, `client_subnets`
- Update security groups for cross-VPC CIDR
- No VPC peering creation (assumes it exists)

**Phase 3: Enhanced Flexibility**
- Per-instance VPC configuration
- Support DCs across multiple VPCs
- Automatic VPC peering (optional)

---

## Quick Reference

### Find VPC IDs

```bash
aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Find Subnets

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' \
  --output table
```

### Verify Peering

```bash
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[?RequesterVpcInfo.VpcId==`vpc-AAAA` && AccepterVpcInfo.VpcId==`vpc-BBBB`]'
```

---

## Summary

**Current capability:** Single VPC deployment (working and tested)

**Future enhancement:** Multi-VPC support with separate DC and client VPCs

**Key requirement:** VPC peering and routes must be configured by network team before deployment

**Implementation effort:** Approximately 2-3 hours to add multi-VPC variable support

**Ansible changes:** None required (works with any network topology)
