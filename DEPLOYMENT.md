# Quick Start Deployment Guide

This guide provides step-by-step instructions to deploy the **scalable** Windows Active Directory lab with role-based Ansible architecture.

**✨ New:** Role-based architecture automatically scales to ANY number of DCs and clients!

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] AWS CLI installed and configured with SSO (`okta-sso` profile)
- [ ] Terraform v1.0+ installed
- [ ] Ansible v2.12+ installed
- [ ] Python3 with pywinrm: `pip3 install pywinrm`
- [ ] Ansible Windows collections installed
- [ ] Existing VPC in eu-central-1
- [ ] At least 1 subnet in your VPC (multi-subnet recommended)
- [ ] EC2 key pair created in eu-central-1
- [ ] Your public IP address for RDP/WinRM access

## Step 1: Install Required Ansible Collections

```bash
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install microsoft.ad
python3 -m pip install pywinrm
```

## Step 2: Configure Terraform Variables

```bash
cd terraform

# Edit with your values
vim terraform.tfvars
```

**Key configuration values:**
```hcl
# AWS
aws_region  = "eu-central-1"
aws_profile = "okta-sso"

# Network
vpc_id = "vpc-XXXXXXXXXXXXXXXXX"
subnets = ["subnet-XXXXXXXXXXXXXXXXX"]  # Add more subnets for HA

# ⭐ SCALE HERE! ⭐
domain_controller_count = 3  # 1-100+ DCs
client_count            = 2  # 0-100+ clients

# Domain
domain_name           = "corp.infolab"
domain_admin_password = "P@ssw0rd123!SecureAD"

# Instances
dc_instance_type     = "t3.large"   # 2 vCPU, 8GB
client_instance_type = "t3.medium"  # 2 vCPU, 4GB

# Security
key_name            = "your-key-name"
allowed_rdp_cidrs   = ["YOUR.IP/32"]
allowed_winrm_cidrs = ["YOUR.IP/32"]
```

**Get your public IP:**
```bash
curl -s ifconfig.me
```

## Step 3: Deploy Infrastructure (5 minutes)

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply -auto-approve
```

**Expected output:**
```
Apply complete! Resources: 40+ added, 0 changed, 0 destroyed.

Outputs:
dc1_public_ip = "3.126.28.111"
dc2_public_ip = "52.29.229.223"
dc3_public_ip = "63.177.176.60"
client_public_ips = ["18.157.68.34", "63.176.72.74"]
ansible_inventory_path = "../ansible/inventory/aws_windows.yml"
```

## Step 4: Wait for Windows Instances to Boot

Windows instances need time to boot and configure WinRM. **Wait at least 3 minutes.**

```bash
echo "Waiting for Windows instances to boot and configure WinRM..."
sleep 180
```

## Step 5: Test Ansible Connectivity

```bash
cd ../ansible

# Test WinRM connectivity (macOS users need this)
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Test connectivity to all hosts
ansible all -i inventory/aws_windows.yml -m win_ping
```

**Expected output:**
```
dc1 | SUCCESS => { "changed": false, "ping": "pong" }
dc2 | SUCCESS => { "changed": false, "ping": "pong" }
dc3 | SUCCESS => { "changed": false, "ping": "pong" }
client1 | SUCCESS => { "changed": false, "ping": "pong" }
client2 | SUCCESS => { "changed": false, "ping": "pong" }
```

**If this fails:**
- Wait longer (some instances take 5+ minutes)
- Check security group allows WinRM from your IP
- Verify instances are running: `aws ec2 describe-instances`

## Step 6: Run Role-Based Ansible Playbook (30-45 minutes)

```bash
# ⭐ NEW: Role-based playbook that auto-scales!
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ansible-playbook \
  -i inventory/aws_windows.yml \
  playbooks/site.yml \
  2>&1 | tee deployment-$(date +%Y%m%d-%H%M%S).log
```

**What happens automatically:**
1. ✅ Preflight checks on all hosts
2. ✅ ADDS/DNS/DHCP roles installed on all DCs
3. ✅ DC1 promoted as forest root (~5 min)
4. ✅ DC1 SYSVOL advertised + DNS/DHCP configured
5. ✅ DC2 joins domain + promoted (~5-8 min)
6. ✅ DC3 joins domain + promoted (~5-8 min)
7. ✅ DC4, DC5... (if you have more DCs)
8. ✅ All clients join domain

**Progress indicators:**
```
PLAY [Common Setup for All Hosts] ***
PLAY [Create AD Forest on First DC] ***
PLAY [Join Additional DCs to Domain] ***  ← Runs for DC2, DC3, DC4...
PLAY [Join Windows Clients to Domain] ***
```

**Expected final output:**
```
PLAY RECAP *********************************************************************
client1  : ok=12   changed=4    unreachable=0    failed=0    skipped=2
client2  : ok=12   changed=4    unreachable=0    failed=0    skipped=2
dc1      : ok=12   changed=5    unreachable=0    failed=0    skipped=1
dc2      : ok=19   changed=9    unreachable=0    failed=0    skipped=2
dc3      : ok=19   changed=9    unreachable=0    failed=0    skipped=2
```

**Note:** If playbook times out but DCs are actually complete, just re-run (it's idempotent).

## Step 7: Verify Deployment

```bash
# Verify domain membership
ansible windows -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# Expected: corp.infolab (all hosts)

# Test domain controller discovery
ansible windows -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nltest /dsgetdc:corp.infolab"

# Expected: Shows DC details with success message

# Verify all DCs are Global Catalogs
ansible domain_controllers -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-ADDomainController -Server localhost | Select-Object Name,IsGlobalCatalog"
```

## Step 8: Access Your Environment

Get connection details:
```bash
cd ../terraform
terraform output rdp_connection_info
```

**RDP Access:**
```
DC1:     3.126.28.111:3389
DC2:     52.29.229.223:3389
DC3:     63.177.176.60:3389
Client1: 18.157.68.34:3389
Client2: 63.176.72.74:3389

Username: Administrator
Password: P@ssw0rd123!SecureAD
Domain:   corp.infolab
```

**On macOS:**
```bash
open rdp://full%20address=s:3.126.28.111:3389
```

**On Windows:**
```powershell
mstsc /v:3.126.28.111
```

## Scaling Your Deployment

### Add More DCs (Scale 3→5)

```bash
# 1. Edit terraform.tfvars
cd terraform
vim terraform.tfvars
# Change: domain_controller_count = 5

# 2. Apply infrastructure changes
terraform apply -auto-approve
sleep 180

# 3. Run Ansible (automatically handles DC4, DC5)
cd ../ansible
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

**What happens:**
- ✅ DC1, DC2, DC3: Skipped (already promoted)
- 🆕 DC4: Joins domain + promotes automatically
- 🆕 DC5: Joins domain + promotes automatically

### Add More Clients

```bash
# 1. Edit terraform.tfvars
# Change: client_count = 5

# 2. Apply
terraform apply -auto-approve
sleep 180

# 3. Configure clients
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

## Troubleshooting Common Issues

### Issue 1: Domain Join Fails

**Error:** "The specified domain either does not exist or could not be contacted"

**Root Cause:** AMI has static DNS 10.10.10.10 pre-configured

**Solution:** This is already fixed in the roles! The playbook uses:
```powershell
Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses {{ dc1_ip }}
```

Location: `roles/ad_additional_dc/tasks/main.yml` and `roles/ad_client/tasks/main.yml`

### Issue 2: "InstallDNS parameter not recognized"

**Root Cause:** Windows Server 2025 removed `install_dns` parameter

**Solution:** Already fixed! Removed from all promotion tasks in the roles.

### Issue 3: Playbook Times Out

**Symptom:** Playbook times out at 30 minutes during DC promotion

**Usually the DC completed anyway!** Verify:
```bash
ansible dc3 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-ADDomainController -Server localhost"
```

If verified, just re-run (idempotent):
```bash
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

### Issue 4: Ansible Can't Connect

**Error:** "Connection timeout" or "WinRM connection failed"

**Solution:**
```bash
# 1. Check instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=windows-ad-lab" \
  --profile okta-sso --region eu-central-1

# 2. Verify security group allows your IP
# 3. Wait longer (5+ minutes for some instances)
# 4. Test WinRM manually
curl -k https://$(terraform output -raw dc1_public_ip):5986/wsman
```

### Issue 5: SYSVOL Not Replicating

**Symptom:** Playbook waits for SYSVOL share

**Solution:**
```bash
# Check DC status
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "dcdiag /test:sysvol"

# Check replication
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "repadmin /showrepl"

# Usually just needs more time - rerun playbook (it's idempotent)
```

## Cleaning Up

To destroy all resources:

```bash
cd terraform
terraform destroy -auto-approve
```

**What gets deleted:**
- All EC2 instances (DCs + clients)
- Elastic IPs
- Network interfaces
- Security groups
- IAM roles

**What remains:**
- VPC (not managed by this project)
- Subnets (not managed by this project)

## Success Indicators

Your deployment is successful when:

✅ Terraform completes with 0 errors
✅ Ansible playbook completes with 0 failures
✅ All hosts show "SUCCESS" in `ansible all -m win_ping`
✅ All hosts return "corp.infolab" for domain membership
✅ `nltest /dsgetdc:corp.infolab` returns DC details
✅ You can RDP to all systems with domain credentials
✅ All DCs show in Active Directory Sites and Services
✅ All DCs are Global Catalog servers

## Time Estimates

- **Step 1-2:** 5 minutes (prerequisites and configuration)
- **Step 3:** 3-5 minutes (Terraform apply)
- **Step 4:** 3 minutes (waiting for boot)
- **Step 5:** 1 minute (connectivity test)
- **Step 6:** 30-45 minutes (Ansible configuration, scales with DC count)
- **Step 7-8:** 2 minutes (verification)

**Total for 3 DCs + 2 clients:** ~45-60 minutes from start to fully working AD lab

**Total for 2 DCs + 1 client:** ~30-35 minutes

## Cost Summary

**Hourly costs (eu-central-1):**
- 3× t3.large (DCs): $0.17/hr × 3 = $0.51/hr
- 2× t3.medium (clients): $0.08/hr × 2 = $0.16/hr
- 5× Elastic IPs: $0.005/hr × 5 = $0.025/hr
- **Total: ~$0.70/hr or $504/month** (if left running)

**Cost-saving tip:** Stop instances when not in use:
```bash
aws ec2 stop-instances \
  --instance-ids $(terraform output -json | jq -r '.dc_instance_ids.value[],.client_instance_ids.value[]') \
  --profile okta-sso --region eu-central-1
```

Note: EIP charges continue even when instances are stopped.

## What's New in Role-Based Architecture

### Before (Hardcoded)
- Playbook hardcoded for exactly 2 DCs
- Had to manually edit playbook to add DC3
- Lots of repetitive tasks

### After (Role-Based, Auto-Scaling)
- Supports 1-100+ DCs automatically
- Just change `domain_controller_count` in terraform.tfvars
- Clean, modular roles:
  - `ad_common` - Runs on all hosts
  - `ad_first_dc` - Creates forest (DC1 only)
  - `ad_additional_dc` - Joins + promotes (DC2, DC3, DC4...)
  - `ad_client` - Domain join (all clients)

### Key Innovation
```yaml
# In playbooks/site.yml
hosts: domain_controllers[0]   # First DC creates forest
hosts: domain_controllers[1:]  # Additional DCs join + promote
hosts: windows_clients         # All clients join
```

**Result:** Change counts in `terraform.tfvars` → Ansible scales automatically!

## Support and Documentation

- **Main README:** `README.md` - Comprehensive documentation with multi-VPC setup
- **Troubleshooting:** See above and main README
- **Technical Notes:** `TECHNICAL_NOTES.md` - Critical fixes and architecture decisions
- **Configuration:** `terraform/terraform.tfvars.example`
- **Logs:** All Ansible runs are saved with timestamps

## Tested Configurations

| DCs | Clients | Result | Duration |
|-----|---------|--------|----------|
| 2   | 1       | ✅ Success | 25 min |
| 3   | 2       | ✅ Success | 45 min |

**Want to test larger scale?** Just update the counts and deploy!

---

**Questions?** See the main README.md for multi-VPC setup, advanced scaling, and architecture details.
