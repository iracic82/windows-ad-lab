# Multi-VPC Deployment with Existing VPC Peering

**Prerequisites:**
- ✅ VPC peering already configured by network team
- ✅ Routes already exist between VPCs
- ✅ You just need to place DCs and clients in the right VPCs

---

## Simple Configuration

### Current terraform.tfvars (Single VPC)

```hcl
# Everything in one VPC
vpc_id  = "vpc-abc123"
subnets = ["subnet-111", "subnet-222"]

domain_controller_count = 3
client_count            = 2
```

### What You Want: DCs in VPC-A, Clients in VPC-B

**Problem:** Current code doesn't support this. You need to specify VPC per instance.

---

## Solution 1: Separate Terraform Deployments (Current Code)

Since current code only supports one VPC, deploy in two steps:

### Step 1: Deploy DCs in VPC-A

```hcl
# terraform-dcs.tfvars
vpc_id  = "vpc-AAAA-for-DCs"
subnets = ["subnet-dc-1", "subnet-dc-2"]

domain_controller_count = 3
client_count            = 0  # No clients
```

```bash
cd terraform
terraform apply -var-file="terraform-dcs.tfvars"
```

### Step 2: Deploy Clients in VPC-B

```hcl
# terraform-clients.tfvars
vpc_id  = "vpc-BBBB-for-clients"
subnets = ["subnet-client-1", "subnet-client-2"]

domain_controller_count = 0  # No DCs
client_count            = 2
```

```bash
terraform apply -var-file="terraform-clients.tfvars"
```

**Problem:** This creates separate Terraform states and inventories. Not ideal.

---

## Solution 2: Modify terraform.tfvars Syntax (Requires Code Change)

To support what you want, we'd need to change the Terraform variables to:

```hcl
# Desired configuration (NOT currently supported)
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

**This would require Terraform code changes to support per-instance VPC configuration.**

---

## Solution 3: Quick Implementation (15 minutes)

I can add these variables to Terraform to support your use case:

### New variables in terraform.tfvars:

```hcl
# Domain Controllers Configuration
dc_vpc_id      = "vpc-AAAA-for-DCs"
dc_subnets     = ["subnet-dc-1", "subnet-dc-2"]
domain_controller_count = 3

# Clients Configuration
client_vpc_id  = "vpc-BBBB-for-clients"
client_subnets = ["subnet-client-1", "subnet-client-2"]
client_count   = 2

# Network team already configured:
# ✅ VPC peering between vpc-AAAA and vpc-BBBB
# ✅ Routes in route tables
# ✅ Security groups allow cross-VPC traffic
```

### What Terraform will do:
- ✅ Deploy DCs in vpc-AAAA using dc_subnets
- ✅ Deploy clients in vpc-BBBB using client_subnets
- ✅ Create security groups that allow traffic between the VPC CIDRs
- ❌ **NO VPC peering** (assumes it exists)
- ❌ **NO route table changes** (assumes routes exist)

---

## What You Need to Provide

Before deployment, get from your network team:

```bash
# Domain Controllers VPC
DC_VPC_ID="vpc-xxxxx"
DC_VPC_CIDR="10.10.0.0/16"
DC_SUBNET_1="subnet-aaa"
DC_SUBNET_2="subnet-bbb"

# Clients VPC
CLIENT_VPC_ID="vpc-yyyyy"
CLIENT_VPC_CIDR="10.20.0.0/16"
CLIENT_SUBNET_1="subnet-xxx"
CLIENT_SUBNET_2="subnet-yyy"

# Verify VPC peering exists
PEERING_ID="pcx-zzzzz"  # Should be "active"

# Verify routes exist
# Route in DC VPC route table: 10.20.0.0/16 → pcx-zzzzz
# Route in Client VPC route table: 10.10.0.0/16 → pcx-zzzzz
```

### Verification Commands

```bash
# Check VPC peering
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

**Expected:** Routes to remote VPC CIDR via peering connection ID.

---

## Configuration File

### terraform.tfvars

```hcl
# ══════════════════════════════════════════════════════
# AWS Configuration
# ══════════════════════════════════════════════════════
aws_region  = "eu-central-1"
aws_profile = "okta-sso"

# ══════════════════════════════════════════════════════
# DOMAIN CONTROLLERS - VPC and Subnets
# ══════════════════════════════════════════════════════
dc_vpc_id  = "vpc-0abc123def456"          # Get from network team
dc_subnets = ["subnet-dc1", "subnet-dc2"] # Get from network team

domain_controller_count = 3

# ══════════════════════════════════════════════════════
# CLIENTS - VPC and Subnets
# ══════════════════════════════════════════════════════
client_vpc_id  = "vpc-0xyz789ghi012"              # Get from network team
client_subnets = ["subnet-client1", "subnet-client2"] # Get from network team

client_count = 2

# ══════════════════════════════════════════════════════
# DOMAIN Configuration
# ══════════════════════════════════════════════════════
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"

# ══════════════════════════════════════════════════════
# INSTANCE Configuration
# ══════════════════════════════════════════════════════
dc_instance_type     = "t3.large"
client_instance_type = "t3.medium"

# ══════════════════════════════════════════════════════
# SECURITY
# ══════════════════════════════════════════════════════
key_name            = "your-key-name"
allowed_rdp_cidrs   = ["YOUR.IP/32"]
allowed_winrm_cidrs = ["YOUR.IP/32"]

# ══════════════════════════════════════════════════════
# NETWORK (Assumes VPC peering already exists!)
# ══════════════════════════════════════════════════════
# VPC peering between dc_vpc_id and client_vpc_id must exist
# Routes must be configured by network team
# Terraform will NOT create peering or routes
```

---

## Deployment

```bash
cd terraform

# Review what will be created
terraform plan

# Deploy
terraform apply

# Result:
# ✅ 3 DCs in vpc-0abc123def456
# ✅ 2 Clients in vpc-0xyz789ghi012
# ✅ Security groups allow cross-VPC traffic
# ✅ Ansible inventory includes all hosts
```

---

## What Terraform Does

### ✅ Creates:
- EC2 instances for DCs in DC VPC
- EC2 instances for clients in Client VPC
- Security groups in each VPC
- Security group rules allowing DC VPC CIDR ↔ Client VPC CIDR

### ❌ Does NOT Create:
- VPC peering (assumes it exists)
- Route table entries (assumes they exist)
- VPC modifications (assumes network team configured)

---

## Security Groups Automatically Configured

Terraform automatically creates rules allowing cross-VPC traffic:

```
DC Security Group (in DC VPC):
✅ Allow from Client VPC CIDR:
   - LDAP (389 TCP/UDP)
   - DNS (53 TCP/UDP)
   - Kerberos (88 TCP/UDP)
   - SMB (445 TCP)
   - RPC (135, 49152-65535 TCP)
   - Global Catalog (3268-3269 TCP)

Client Security Group (in Client VPC):
✅ Allow from DC Security Group (same VPC):
   - Not applicable, different VPCs
✅ Allow from DC VPC CIDR:
   - All responses from DCs
```

---

## Ansible - No Changes

Ansible works the same:

```bash
cd ../ansible

# Test connectivity
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible all -i inventory/aws_windows.yml -m win_ping

# Deploy AD
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

Ansible uses private IPs, VPC boundaries are transparent.

---

## Quick Reference

### Find Your VPC IDs

```bash
aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table \
  --profile okta-sso
```

### Find Subnets in a VPC

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' \
  --output table \
  --profile okta-sso
```

### Verify VPC Peering Exists

```bash
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[?RequesterVpcInfo.VpcId==`vpc-AAAA` && AccepterVpcInfo.VpcId==`vpc-BBBB`]' \
  --profile okta-sso
```

---

## Summary

**Current limitation:** Code only supports one VPC for all resources.

**What you need:** DCs in one VPC, clients in another (peering exists).

**Quickest solution:**
1. I add `dc_vpc_id`, `dc_subnets`, `client_vpc_id`, `client_subnets` variables
2. Terraform uses them to place resources in correct VPCs
3. Terraform creates security groups with correct CIDR rules
4. Terraform does NOT create VPC peering (assumes it exists)

**Implementation time:** 15 minutes to add variables and update module calls.

**Want me to implement this?** I'll add the variables and update the Terraform code to support placing DCs and clients in different VPCs (without touching peering).
