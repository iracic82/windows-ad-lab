# Troubleshooting Guide - Windows AD Lab

Comprehensive troubleshooting guide for both AWS and Azure deployments.

## 📋 Quick Links

- **AWS Deployment:** [README.md](README.md)
- **Azure Deployment:** [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)
- **Technical Details:** [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)
- **Setup Guide:** [GETTING_STARTED.md](GETTING_STARTED.md)

---

## Table of Contents

1. [Cloud Provider Issues](#cloud-provider-issues)
   - [AWS Authentication](#aws-authentication)
   - [Azure Authentication](#azure-authentication)
2. [Terraform Issues](#terraform-issues)
3. [Network & Connectivity Issues](#network--connectivity-issues)
4. [Ansible & WinRM Issues](#ansible--winrm-issues)
5. [Active Directory Issues](#active-directory-issues)
6. [Common Error Messages](#common-error-messages)
7. [Diagnostic Commands](#diagnostic-commands)

---

## Cloud Provider Issues

### AWS Authentication

#### Error: "Unable to locate credentials"

```bash
# Verify AWS credentials
aws sts get-caller-identity --profile okta-sso

# If SSO expired, re-login
aws sso login --profile okta-sso

# Check profile configuration
cat ~/.aws/config
cat ~/.aws/credentials
```

#### Error: "You must specify a region"

```bash
# Set default region
export AWS_DEFAULT_REGION=eu-central-1

# Or add to terraform.tfvars
aws_region = "eu-central-1"
```

#### Error: "AWS Profile not found"

```bash
# List available profiles
aws configure list-profiles

# Configure the profile in terraform.tfvars
aws_profile = "your-profile-name"
```

### Azure Authentication

#### Error: "No subscriptions found"

```bash
# Re-login to Azure
az login

# List subscriptions
az account list --output table

# Set correct subscription
az account set --subscription "SUBSCRIPTION_ID"

# Verify
az account show
```

#### Error: "Subscription not found"

```bash
# Check subscription ID in terraform.tfvars.azure
# Get correct subscription ID
az account show --query id -o tsv

# Update terraform.tfvars.azure
azure_subscription_id = "correct-subscription-id"
```

#### Error: "Insufficient privileges"

```bash
# Check your role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv)

# You need at least "Contributor" role
# Contact your Azure admin if lacking permissions
```

---

## Terraform Issues

### Error: "Failed to query available provider packages"

```bash
# Reinitialize Terraform
cd terraform/aws  # or terraform/azure
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Error: "Resource already exists"

```bash
# Import existing resource
terraform import <resource_type>.<name> <resource_id>

# Or destroy and recreate
terraform destroy -target=<resource>
terraform apply
```

### Error: "No available IP addresses in subnet"

**AWS:**
```bash
# Check subnet CIDR and available IPs
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailableIpAddressCount'

# Use different subnet or expand CIDR
```

**Azure:**
```bash
# Check subnet available IPs
az network vnet subnet show \
  --resource-group my-rg \
  --vnet-name my-vnet \
  --name my-subnet \
  --query "addressPrefix"
```

### Error: "Invalid CIDR block"

```bash
# Verify CIDR blocks don't overlap
# AWS: Check VPC CIDR
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx

# Azure: Check VNet CIDR
az network vnet show --resource-group my-rg --name my-vnet
```

### Error: "terraform.tfvars not found"

```bash
# AWS deployment
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Azure deployment
cd terraform/azure
cp terraform.tfvars.azure.example terraform.tfvars.azure
vim terraform.tfvars.azure
```

---

## Network & Connectivity Issues

### Issue: "Cannot connect to public IP"

**Verify Security Groups/NSGs:**

**AWS:**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify your current IP
curl ifconfig.me

# Update allowed_rdp_cidrs in terraform.tfvars
```

**Azure:**
```bash
# Check NSG rules
az network nsg show --resource-group windows-ad-lab-rg \
  --name windows-ad-lab-dc-nsg

# Verify inbound rules
az network nsg rule list --resource-group windows-ad-lab-rg \
  --nsg-name windows-ad-lab-dc-nsg --output table
```

### Issue: "VNet peering not working" (Azure)

```bash
# Check peering status
az network vnet peering list \
  --resource-group windows-ad-lab-rg \
  --vnet-name windows-ad-lab-dc-vnet \
  --output table

# Peering status should be "Connected"
# If not, check:
# 1. Both peering connections exist (bidirectional)
# 2. Address spaces don't overlap
# 3. Route tables are configured correctly
```

### Issue: "DNS resolution failing"

**Check DNS configuration:**
```bash
# From Ansible control node
ansible all -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-DnsClientServerAddress"

# Should show DC1 IP (10.10.10.5 for AWS, 10.0.1.5 for Azure)
```

**Verify DNS is working:**
```bash
# Test DNS from client
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nslookup corp.infolab"

# Should resolve to DC1 IP
```

---

## Ansible & WinRM Issues

### Error: "winrm or requests is not installed"

```bash
# Install Python dependencies
python3 -m pip install --upgrade pywinrm requests

# Verify installation
python3 -c "import winrm; print(winrm.__version__)"
```

### Error: "Failed to connect to WinRM"

**Checklist:**
1. **Wait 5 minutes** after VM creation for WinRM to initialize
2. **Check security groups** allow your IP on port 5985
3. **Verify public IP** is assigned to instance
4. **Test connectivity** with curl

```bash
# Test WinRM endpoint (should return 404, not timeout)
curl -v http://PUBLIC_IP:5985/wsman

# Check with verbose Ansible
ansible all -i inventory/aws_windows.yml -m win_ping -vvv
```

### Error: "401 Unauthorized" (WinRM)

```bash
# Verify credentials in inventory file
cat ansible/inventory/aws_windows.yml  # or azure_windows.yml

# Check password matches terraform.tfvars
# ansible_password should match domain_admin_password
```

### Error: "Connection timeout" (WinRM)

```bash
# Check VM is running
terraform output  # Shows public IPs

# AWS: Check instance status
aws ec2 describe-instances --instance-ids i-xxxxx

# Azure: Check VM status
az vm get-instance-view \
  --resource-group windows-ad-lab-rg \
  --name windows-ad-lab-DC1
```

### Issue: "Ansible playbook hangs"

```bash
# macOS users: Set fork safety variable
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Run with verbose output
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml -vv

# Check if specific host is causing issue
ansible dc1 -i inventory/aws_windows.yml -m win_ping
```

---

## Active Directory Issues

### Error: "Domain does not exist"

**This is usually a DNS issue.** See [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) for the critical fix.

**Quick check:**
```bash
# Verify DNS is set to DC1
ansible dc2 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses"

# Should show DC1 IP (10.10.10.5 or 10.0.1.5)
```

**Fix DNS:**
```bash
# This is handled automatically by Ansible roles
# If you need to manually fix:
ansible dc2 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses 10.10.10.5"
```

### Error: "Domain join failed"

**Common causes:**
1. **DNS not pointing to DC1**
2. **DC1 not fully promoted** (wait for SYSVOL)
3. **Network connectivity issues**
4. **Time synchronization problems**

**Diagnostic steps:**
```bash
# 1. Check DC1 status
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "dcdiag /test:advertising"

# 2. Check SYSVOL is shared
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Test-Path \\localhost\SYSVOL"

# 3. Verify network connectivity
ansible client1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Test-NetConnection -ComputerName 10.10.10.5 -Port 389"

# 4. Check time synchronization
ansible all -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "w32tm /query /status"
```

### Error: "SYSVOL replication not working"

```bash
# Check SYSVOL status
ansible dc2 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-Service DFSR,NETLOGON | Select-Object Name,Status"

# Check DFS replication
ansible dc2 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "dfsrdiag ReplicationState /all"

# Wait time: SYSVOL can take 5-10 minutes to replicate
```

### Issue: "DC promotion times out"

**This is often normal!** The playbook times out but DC promotion continues.

**Verify DC status:**
```bash
# Check if DC is actually promoted
ansible dc2 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-ADDomainController -Server localhost"

# If successful, just re-run the playbook (idempotent)
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml
```

---

## Common Error Messages

### "install_dns parameter not recognized" (Windows Server 2025)

**Cause:** Microsoft removed `install_dns` parameter in Server 2025.

**Fix:** Already fixed in project. DNS installs automatically.

**Reference:** [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md#windows-server-2025-compatibility)

### "Pre-configured DNS 10.10.10.10"

**Cause:** Windows AMI has static DNS pre-configured.

**Fix:** Ansible roles automatically fix this with PowerShell cmdlet.

**Reference:** [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md#dns-pre-configuration-fix-10101010)

### "LDAP UDP port 389 not accessible"

**Cause:** Security groups missing UDP 389 rule.

**Fix:** Already included in Terraform security groups.

**Reference:** [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md#critical-fix-ldap-udp-port-389)

### "VPC DNS hostnames not enabled" (AWS Only)

**Cause:** VPC DNS hostnames disabled.

**Fix:**
```bash
aws ec2 modify-vpc-attribute \
  --vpc-id vpc-xxxxx \
  --enable-dns-hostnames \
  --profile okta-sso
```

### "Quota exceeded"

**AWS:**
```bash
# Check EC2 limits
aws service-quotas list-service-quotas \
  --service-code ec2 | grep -A3 "Running On-Demand"
```

**Azure:**
```bash
# Check quota
az vm list-usage --location eastus --output table

# Request increase via Azure Portal if needed
```

---

## Diagnostic Commands

### Quick Health Check

**All Platforms:**
```bash
# 1. Test WinRM connectivity
ansible all -i inventory/<platform>_windows.yml -m win_ping

# 2. Check domain membership
ansible all -i inventory/<platform>_windows.yml \
  -m ansible.windows.win_shell \
  -a "(Get-WmiObject Win32_ComputerSystem).Domain"

# 3. Verify AD replication
ansible domain_controllers -i inventory/<platform>_windows.yml \
  -m ansible.windows.win_shell \
  -a "repadmin /replsummary"
```

### Deep Diagnostics

```bash
# DC health check
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "dcdiag /v"

# DNS check
ansible all -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "nslookup corp.infolab"

# Network services
ansible all -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-Service | Where-Object {$_.Status -eq 'Running'} | Select-Object Name"

# Event logs (last 10 errors)
ansible dc1 -i inventory/aws_windows.yml \
  -m ansible.windows.win_shell \
  -a "Get-EventLog -LogName System -EntryType Error -Newest 10 | Select-Object TimeGenerated,Source,Message"
```

### Platform-Specific Diagnostics

**AWS:**
```bash
# Check instance console output
aws ec2 get-console-output --instance-id i-xxxxx

# Check security groups
terraform output | grep security_group

# Check instance status
aws ec2 describe-instance-status --instance-ids i-xxxxx
```

**Azure:**
```bash
# Check VM boot diagnostics
az vm boot-diagnostics get-boot-log \
  --resource-group windows-ad-lab-rg \
  --name windows-ad-lab-DC1

# Check NSG rules
az network nsg show \
  --resource-group windows-ad-lab-rg \
  --name windows-ad-lab-dc-nsg

# Check VM status
az vm list -d --output table
```

---

## Re-running After Failures

### Ansible Playbook Failed Mid-Run

**Good news:** The playbook is idempotent - safe to re-run!

```bash
# Just re-run the same command
cd ansible
ansible-playbook -i inventory/aws_windows.yml playbooks/site.yml

# Ansible will:
# - Skip already completed tasks
# - Continue from where it failed
# - Not duplicate any resources
```

### Partial Terraform Deployment

```bash
# Review what's created
terraform show

# Complete the deployment
terraform apply

# Or start fresh
terraform destroy
terraform apply
```

---

## Getting Help

### Information to Collect

When asking for help, provide:

1. **Platform:** AWS or Azure
2. **Error message:** Full error output
3. **Terraform version:** `terraform --version`
4. **Ansible version:** `ansible --version`
5. **Deployment logs:** Content of log files if using deploy scripts
6. **Current state:**
   ```bash
   terraform output
   ansible all -i inventory/<platform>_windows.yml -m win_ping
   ```

### Useful Log Files

```bash
# Ansible playbook logs (if using deploy scripts)
cat /tmp/ansible-aws-2dc-2client.log
cat /tmp/ansible-azure-3dc-2client.log

# Terraform logs
export TF_LOG=DEBUG
terraform apply 2>&1 | tee terraform-debug.log
```

---

## Prevention Tips

### Before Deploying

1. ✅ **Verify credentials:** Test AWS/Azure CLI access
2. ✅ **Check quotas:** Ensure sufficient cloud resource limits
3. ✅ **Update variables:** Double-check terraform.tfvars
4. ✅ **Get your IP:** Use `curl ifconfig.me` for security groups
5. ✅ **Read docs:** Review platform-specific guide

### During Deployment

1. ✅ **Monitor progress:** Watch terraform/ansible output
2. ✅ **Wait patiently:** AD configuration takes 30-45 minutes
3. ✅ **Don't interrupt:** Let playbooks complete

### After Deployment

1. ✅ **Verify connectivity:** Test win_ping
2. ✅ **Check domain:** Verify all hosts joined
3. ✅ **Test RDP:** Ensure you can connect
4. ✅ **Save logs:** Keep deployment logs for reference

---

## Related Documentation

- **[README.md](README.md)** - AWS deployment guide
- **[AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)** - Azure deployment guide
- **[TECHNICAL_NOTES.md](TECHNICAL_NOTES.md)** - Critical fixes and implementation details
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup guide
- **[PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md)** - AWS vs Azure comparison

---

## Still Having Issues?

1. Check [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) for known issues and fixes
2. Review the platform-specific troubleshooting sections in:
   - [README.md](README.md#troubleshooting) (AWS)
   - [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md#troubleshooting) (Azure)
3. Open an issue on GitHub with detailed information
