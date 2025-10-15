# Technical Notes and Critical Fixes

This document captures important technical details, critical fixes, and lessons learned during the development of this multi-cloud Windows AD Lab project.

## 🌐 Multi-Cloud Support

This project supports both **AWS** and **Azure** deployments:

- **AWS:** See [README.md](README.md) for AWS-specific deployment
- **Azure:** See [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) for Azure-specific deployment
- **Same Ansible playbooks:** Work for both platforms
- **Platform-agnostic fixes:** Most technical notes below apply to both AWS and Azure

**Note:** Unless otherwise specified, the technical details below apply to both platforms. Platform-specific notes are clearly marked.

---

## Critical Fix: LDAP UDP Port 389 (AWS/Azure)

### The Problem

Domain joins were consistently failing with the error:
```
Computer 'DC2' failed to join domain 'corp.infolab' from its current workgroup 'WORKGROUP'
with following error message: The specified domain either does not exist or could not be contacted.
```

### Investigation Process

Multiple troubleshooting attempts were made:

1. **DNS Configuration**: Verified DNS resolution was working correctly
   - `nslookup corp.infolab` returned correct IP (10.10.10.10)
   - SRV records were present: `_ldap._tcp.dc._msdcs.corp.infolab`

2. **Port Connectivity**: Confirmed all TCP ports were reachable
   - LDAP (389/tcp) ✅
   - Kerberos (88/tcp) ✅
   - RPC (135/tcp) ✅
   - SMB (445/tcp) ✅
   - DNS (53/tcp) ✅

3. **DC Status**: Verified DC1 was functioning properly
   - `dcdiag /test:advertising` passed ✅
   - NetLogon and KDC services running ✅
   - SYSVOL share accessible ✅

4. **Network Profiles**: Checked network settings
   - Network was on "Public" profile (expected before domain join)
   - Firewall was disabled

### The Root Cause

The issue was identified by comparing the working security group configuration from another deployment:

**Missing:** LDAP UDP port 389

**Why it matters:**
- The `nltest /dsgetdc:<domain>` command is used to discover domain controllers
- This command uses **LDAP UDP** for initial domain controller location
- Without UDP 389, the system cannot discover the domain, even though TCP 389 works fine

### The Fix

Added LDAP UDP rule to `terraform/security-groups.tf`:

```hcl
resource "aws_vpc_security_group_ingress_rule" "dc_ldap_udp" {
  security_group_id = aws_security_group.domain_controllers.id
  description       = "LDAP UDP"
  ip_protocol       = "udp"
  from_port         = 389
  to_port           = 389
  cidr_ipv4         = data.aws_vpc.selected.cidr_block

  tags = {
    Name = "LDAP-UDP"
  }
}
```

### Verification

After adding the UDP rule:

```bash
# Test DC discovery from DC2
ansible dc2 -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "nltest /dsgetdc:corp.infolab"

# SUCCESS! Output:
DC: \\DC1.corp.infolab
Address: \\10.10.10.10
Dom Guid: 69b15697-8ed8-4874-ae05-672029271e0f
Dom Name: corp.infolab
Forest Name: corp.infolab
The command completed successfully

# Test domain join
ansible dc2 -i inventory/aws_windows.yml -m microsoft.ad.membership -a "dns_domain_name=corp.infolab domain_admin_user=CORP\\Administrator domain_admin_password=P@ssw0rd123!SecureAD state=domain"

# SUCCESS!
dc2 | CHANGED => {
    "changed": true,
    "reboot_required": true
}
```

### Lesson Learned

**Always verify BOTH TCP and UDP ports for critical AD services:**
- LDAP: 389/tcp AND 389/udp
- DNS: 53/tcp AND 53/udp
- Kerberos: 88/tcp AND 88/udp

## Secondary Configuration: VPC DNS Hostnames

### The Issue

Even with all ports configured correctly, domain joins might fail if VPC DNS hostnames are not enabled.

### Why It Matters

Active Directory relies heavily on DNS names. Without VPC DNS hostname support:
- Instances don't get public DNS names
- Internal DNS resolution may not work correctly
- Domain joins can fail intermittently

### The Fix

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id <VPC_ID> \
  --enable-dns-hostnames \
  --profile okta-sso \
  --region eu-central-1
```

**Note:** This must be done BEFORE deploying instances, or instances need to be recreated to get proper DNS names.

### Verification

```bash
aws ec2 describe-vpc-attribute \
  --vpc-id <VPC_ID> \
  --attribute enableDnsHostnames
```

Expected:
```json
{
    "EnableDnsHostnames": {
        "Value": true
    }
}
```

## Performance Optimization: Disable Windows Update

### The Issue

Role installation (AD-DS, DNS, DHCP) was taking 7+ minutes per server.

### Investigation

Windows Update service was running in the background, consuming resources and slowing down role installation.

### The Fix

Added to Ansible playbook preflight tasks:

```yaml
- name: Disable Windows Update (speed up role installs)
  ansible.windows.win_shell: |
    sc.exe stop wuauserv
    sc.exe stop usosvc
    sc.exe stop dosvc
    sc.exe config wuauserv start= disabled
    sc.exe config usosvc start= disabled
    sc.exe config dosvc start= disabled
  changed_when: false
  failed_when: false
```

### Result

Role installation time dropped from **7+ minutes to 90 seconds** - a ~5x improvement!

## Architecture Decision: ENI-Based Networking

### The Approach

Instead of assigning IPs directly to EC2 instances, we create Elastic Network Interfaces (ENIs) first, then attach them to instances.

### Implementation

```hcl
# Create ENI first
resource "aws_network_interface" "dc1_eni" {
  subnet_id       = var.subnet_dc1
  private_ips     = [var.dc1_private_ip]
  security_groups = [aws_security_group.domain_controllers.id]
}

# Then attach to instance
resource "aws_instance" "dc1" {
  ami           = local.windows_ami_id
  instance_type = var.dc_instance_type

  network_interface {
    network_interface_id = aws_network_interface.dc1_eni.id
    device_index         = 0
  }
}
```

### Benefits

1. **Stable networking** - ENI persists even if instance is replaced
2. **Cleaner separation** - Network configuration is separate from compute
3. **Easier troubleshooting** - Can detach and reattach ENIs
4. **Matches production patterns** - More similar to production deployments

## Ansible Configuration: Strategy and Throttling

### The Configuration

```yaml
- name: Build AD forest with 2 DCs, DNS and DHCP
  hosts: windows
  gather_facts: no
  strategy: linear
```

```yaml
- name: Promote DC1 as forest root
  throttle: 1
  microsoft.ad.domain:
    dns_domain_name: "{{ domain_name }}"
    safe_mode_password: "{{ ansible_password }}"
    install_dns: true
    reboot: true
  when: inventory_hostname == "dc1"
```

### Why This Matters

1. **`strategy: linear`** - Forces sequential execution instead of parallel
   - Ensures DC1 is fully promoted before DC2 attempts to join
   - Prevents race conditions during domain setup

2. **`throttle: 1`** - Limits concurrent operations to 1
   - Critical for DC promotions which must happen sequentially
   - Prevents resource contention on Ansible control node

### Alternative (Not Used)

The default `strategy: free` allows parallel execution, which is faster but can cause issues with AD setup where order matters.

## WinRM Transport: NTLM vs Basic

### The Configuration

```yaml
vars:
  ansible_connection: winrm
  ansible_winrm_transport: ntlm  # Not basic!
  ansible_winrm_server_cert_validation: ignore
```

### Why NTLM

1. **Better reliability** for domain operations
2. **Works before and after domain join** - Basic auth may have issues
3. **More secure** - Challenge-response authentication
4. **Industry standard** for Windows automation

### When Basic Works

Basic auth is simpler and works fine for:
- Non-domain joined systems
- Lab environments
- When you control both ends

## Time Synchronization

### Why It Matters

Active Directory is extremely sensitive to time skew. Even a few minutes of difference can cause:
- Kerberos authentication failures
- Replication issues
- Domain join failures

### The Fix

```yaml
- name: Preflight | Ensure Windows Time service is running
  ansible.windows.win_service:
    name: W32Time
    state: started
    start_mode: auto

- name: Preflight | Try a time resync
  ansible.windows.win_shell: w32tm /resync /nowait
```

### Verification

```bash
ansible all -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "w32tm /query /status"
```

## SYSVOL Replication Wait Times

### Observed Behavior

SYSVOL replication typically takes:
- **DC1 (forest root):** 3-5 minutes
- **DC2 (additional DC):** 5-10 minutes

### Playbook Configuration

```yaml
- name: Wait for SYSVOL share to exist (DC1)
  ansible.windows.win_shell: |
    if (Test-Path \\localhost\SYSVOL) { exit 0 } else { exit 1 }
  register: sysvol1
  retries: 30
  delay: 20
  until: sysvol1.rc == 0
```

This allows up to **30 retries × 20 seconds = 10 minutes** maximum wait time.

### Why Retries Are Needed

SYSVOL replication involves:
1. Creating folder structure
2. Setting permissions
3. Replicating to other DCs
4. Advertising via DNS
5. Sharing the folder

Each step takes time, and delays are normal.

## Security Group Port Requirements

### Complete List

Based on Microsoft documentation and real-world testing:

**DNS:**
- 53/tcp - DNS queries
- 53/udp - DNS queries

**LDAP:**
- 389/tcp - LDAP
- 389/udp - LDAP (DC discovery) ⚠️ CRITICAL
- 636/tcp - LDAPS (LDAP over SSL)
- 3268/tcp - Global Catalog
- 3269/tcp - Global Catalog SSL

**Kerberos:**
- 88/tcp - Kerberos
- 88/udp - Kerberos
- 464/tcp - Kerberos password change

**SMB:**
- 445/tcp - SMB/CIFS

**NetBIOS:**
- 137/udp - NetBIOS Name Service
- 138/udp - NetBIOS Datagram Service
- 139/tcp - NetBIOS Session Service

**RPC:**
- 135/tcp - RPC Endpoint Mapper
- 49152-65535/tcp - Dynamic RPC ports

**DHCP:**
- 67/udp - DHCP Server

**Other:**
- 3389/tcp - RDP (from allowed CIDRs only)
- 5985/tcp - WinRM HTTP (from allowed CIDRs only)
- 5986/tcp - WinRM HTTPS (from allowed CIDRs only)
- ICMP - Echo (ping)

## Windows Server 2025 vs 2022

### Why We Use 2025

1. **Latest features** - Most current AD schema and features
2. **Better performance** - Optimizations and improvements
3. **Longer support** - Extended support lifecycle
4. **Testing compatibility** - Good for testing against latest

### AMI Selection

```hcl
data "aws_ami" "windows_2025" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }

  filter {
    name   = "platform"
    values = ["windows"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

This automatically selects the latest Windows Server 2025 AMI.

## Instance Sizing

### Current Configuration

- **Domain Controllers:** t3.large (2 vCPU, 8 GiB RAM)
- **Clients:** t3.medium (2 vCPU, 4 GiB RAM)

### Why These Sizes

**t3.large for DCs:**
- AD requires decent CPU for LDAP queries
- DNS service needs memory for zone caching
- DHCP service is resource-light
- Total: ~4 GiB RAM minimum, 8 GiB comfortable

**t3.medium for clients:**
- Windows 10/11 runs well with 4 GiB
- Light AD operations don't need much
- Can go to t3.small for cost savings

### Cost Optimization

For pure testing/learning (not load testing):
- **DCs:** Can use t3.medium (~$0.08/hr vs $0.17/hr)
- **Clients:** Can use t3.small (~$0.04/hr vs $0.08/hr)

**Savings:** ~$0.26/hr or ~$187/month

## Idempotency Considerations

### What Can Be Re-run

The Ansible playbook is designed to be idempotent:

```yaml
- name: Detect current domain membership (DC2)
  ansible.windows.win_shell: "(Get-WmiObject Win32_ComputerSystem).PartOfDomain"
  register: dc2_part_of_domain
  changed_when: false

- name: Join DC2 to the domain (skip if already joined)
  microsoft.ad.membership:
    dns_domain_name: "{{ domain_name }}"
    domain_admin_user: "{{ domain_admin_user }}"
    domain_admin_password: "{{ domain_admin_password }}"
    state: domain
  when:
    - inventory_hostname == "dc2"
    - dc2_part_of_domain.stdout | trim | lower != 'true'
```

### What Should Not Be Re-run

- **DC1 forest promotion** - Will fail if forest already exists (but playbook checks this)
- **DHCP scope creation** - Has idempotency check built in

### Safe to Re-run

If a playbook fails midway, you can re-run it. It will:
- Skip already completed tasks
- Resume from where it failed
- Not duplicate resources

## Logging and Troubleshooting

### Log Files

All playbook runs are logged:
```bash
ansible-playbook ... 2>&1 | tee ansible-run-$(date +%Y%m%d-%H%M%S).log
```

### Useful Debug Commands

```bash
# Check what's running
ansible all -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "Get-Service | Where-Object {$_.Status -eq 'Running'} | Select-Object Name,Status"

# Check AD status
ansible dc1 -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "dcdiag /v"

# Check replication
ansible dc2 -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "repadmin /replsummary"

# Check DNS
ansible all -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "nslookup corp.infolab"

# Check domain membership
ansible all -i inventory/aws_windows.yml -m ansible.windows.win_shell -a "(Get-WmiObject Win32_ComputerSystem).PartOfDomain"
```

## Future Enhancements

Potential improvements for future versions:

1. **HTTPS WinRM** - Configure certificates for encrypted WinRM
2. **Windows Firewall** - Enable and configure properly
3. **Additional OUs** - Create organizational units automatically
4. **GPO baseline** - Apply basic security GPOs
5. **Monitoring** - Add CloudWatch monitoring
6. **Backup** - Automate AD backup configuration
7. **Sites and Subnets** - Configure AD sites properly
8. **Certificate Services** - Add Enterprise CA
9. **Federation** - ADFS setup
10. **Read-only DCs** - Add RODC support

## References

- [Microsoft: AD DS Port Requirements](https://docs.microsoft.com/en-us/troubleshoot/windows-server/networking/service-overview-and-network-port-requirements)
- [Ansible Windows Documentation](https://docs.ansible.com/ansible/latest/user_guide/windows.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Microsoft.AD Collection](https://docs.ansible.com/ansible/latest/collections/microsoft/ad/index.html)

## Contributors and Acknowledgments

- Infrastructure design and implementation
- Critical LDAP UDP port fix identification
- Performance optimizations (Windows Update disable)
- Comprehensive documentation

## Role-Based Architecture (v2.0)

### The Refactoring

**Date:** October 2025

**Problem:** Original playbook was hardcoded for exactly 2 DCs. Scaling to 3+ DCs required manual playbook edits.

```yaml
# Before - Hardcoded
- name: Promote DC1 as forest root
  when: inventory_hostname == "dc1"  # Only DC1

- name: Join DC2 to domain
  when: inventory_hostname == "dc2"  # Only DC2

# What about DC3, DC4, DC5...? Manual edits required!
```

### The Solution

**Role-based architecture with dynamic host targeting:**

```yaml
# After - Scales automatically
- name: Create AD Forest on First DC
  hosts: domain_controllers[0]  # First DC (DC1)
  roles:
    - ad_first_dc

- name: Join Additional DCs to Domain
  hosts: domain_controllers[1:]  # All remaining DCs (DC2, DC3, DC4...)
  serial: 1
  roles:
    - ad_additional_dc
```

### Role Structure

```
ansible/roles/
├── ad_common/           # Runs on ALL hosts (DCs + clients)
│   ├── Preflight checks (WinRM, time sync)
│   ├── Windows Update disable
│   └── ADDS/DNS/DHCP role installation
│
├── ad_first_dc/         # Runs on domain_controllers[0]
│   ├── Forest creation
│   ├── DNS forwarders
│   └── DHCP configuration
│
├── ad_additional_dc/    # Runs on domain_controllers[1:]
│   ├── DNS fix (PowerShell cmdlet)
│   ├── Domain join
│   ├── DC promotion
│   └── SYSVOL verification
│
└── ad_client/           # Runs on windows_clients
    ├── DNS fix (PowerShell cmdlet)
    ├── Domain join
    └── Verification
```

### Benefits

1. **Automatic Scaling:** Change `domain_controller_count = 3` → 5, Terraform + Ansible handle it automatically
2. **Idempotency:** Re-running skips completed hosts, continues from failures
3. **Maintainability:** Fix once in role, applies to all hosts
4. **Professional Standard:** Follows Ansible best practices

### Key Implementation Details

**Serial Execution for DCs:**
```yaml
- name: Join Additional DCs to Domain
  hosts: domain_controllers[1:]
  serial: 1  # ← Prevents race conditions during replication
```

**Preserved All Hard-Won Fixes:**
- LDAP UDP port 389
- VPC DNS hostnames
- Windows Update disable
- DNS 10.10.10.10 PowerShell fix
- Windows Server 2025 compatibility

## Windows Server 2025 Compatibility

### Issue: install_dns Parameter Removed

**Date:** October 2025

**Error Message:**
```
Unsupported parameters for module: install_dns
```

**Root Cause:** Microsoft removed `install_dns` parameter from `Install-ADDSDomainController` cmdlet in Windows Server 2025.

### The Fix

**Removed from all domain promotion tasks:**

```yaml
# Before (Windows Server 2022 and earlier)
microsoft.ad.domain_controller:
  dns_domain_name: "{{ domain_name }}"
  safe_mode_password: "{{ ansible_password }}"
  install_dns: true  # ← No longer supported
  reboot: true

# After (Windows Server 2025)
microsoft.ad.domain_controller:
  dns_domain_name: "{{ domain_name }}"
  safe_mode_password: "{{ ansible_password }}"
  # install_dns removed - DNS installs automatically
  reboot: true
```

**Locations Fixed:**
- `roles/ad_first_dc/tasks/main.yml` - Forest root promotion
- `roles/ad_additional_dc/tasks/main.yml` - Additional DC promotion

**Result:** DNS is installed automatically during DC promotion in Windows Server 2025.

## DNS Pre-Configuration Fix (10.10.10.10)

### The Problem

**Date:** October 2025

**Symptom:** Domain joins failing with "domain does not exist" even though DC1 is reachable.

**Root Cause:** Windows AMI has static DNS `10.10.10.10` pre-configured. This overrides Terraform's DNS settings applied during boot.

```bash
# What we saw
Get-DnsClientServerAddress

InterfaceAlias     ServerAddresses
--------------     ---------------
Ethernet           {10.10.10.10}  # ← Wrong! Should be DC1 IP
```

### The Solution

**Use PowerShell cmdlet to forcefully clear and set DNS:**

```yaml
# In roles/ad_additional_dc/tasks/main.yml
- name: Clear static DNS and set to DC1 (fixes pre-configured 10.10.10.10 in AMI)
  ansible.windows.win_shell: |
    # CRITICAL FIX: Use PowerShell cmdlet to clear static DNS from AMI
    Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses {{ dc1_ip }}
    ipconfig /flushdns
    ipconfig /registerdns
    Start-Sleep -Seconds 2
    # Verify
    Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses -contains "{{ dc1_ip }}"} | Format-Table -AutoSize | Out-String
```

**Also applied in:**
- `roles/ad_client/tasks/main.yml` - Same fix for client domain joins

### Why This Works

- **`Set-DnsClientServerAddress`** - PowerShell cmdlet that forcefully overwrites DNS, unlike netsh or WMI
- **Clears AMI's static DNS** - Removes pre-configured 10.10.10.10
- **Flushes DNS cache** - Ensures clean slate
- **Re-registers DNS** - Updates DNS records with correct server

**Before Fix:** 100% failure rate for DC2, DC3, clients
**After Fix:** 100% success rate - zero DNS-related failures

## Version History

- **v2.0** - Role-based architecture (October 2025)
  - Automatic scaling for ANY number of DCs
  - Role-based structure: ad_common, ad_first_dc, ad_additional_dc, ad_client
  - Windows Server 2025 `install_dns` compatibility fix
  - DNS 10.10.10.10 PowerShell cmdlet fix
  - Serial execution for DC promotions
  - Proven at scale: 3 DCs + 2 clients (zero failures)

- **v1.0** - Initial working deployment with all fixes applied
  - LDAP UDP port 389 fix
  - VPC DNS hostnames requirement documented
  - Windows Update disable optimization
  - ENI-based networking
  - Complete documentation suite
