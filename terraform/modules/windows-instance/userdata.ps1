<powershell>
# ============================================================================
# Windows Instance User Data Script
# Configures Administrator password and WinRM for Ansible
# ============================================================================

# Set Administrator password
$Password = ConvertTo-SecureString "${admin_password}" -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $Password

# Rename computer (will require reboot)
Rename-Computer -NewName "${computer_name}" -Force -ErrorAction SilentlyContinue

# Configure WinRM for Ansible
Write-Host "Configuring WinRM for Ansible..."

# Enable WinRM
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM settings
winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{CredSSP="true"}'

# Set WinRM to start automatically
Set-Service -Name WinRM -StartupType Automatic

# Configure firewall for WinRM
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "Windows Remote Management (HTTP-In)" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "Windows Remote Management (HTTPS-In)" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -ErrorAction SilentlyContinue

# Ensure WinRM is running
Restart-Service WinRM

Write-Host "WinRM configuration complete"

# Set timezone to UTC (optional)
Set-TimeZone -Id "UTC" -ErrorAction SilentlyContinue

# Ensure Windows Time service is running
Set-Service -Name W32Time -StartupType Automatic
Start-Service -Name W32Time -ErrorAction SilentlyContinue
w32tm /resync /nowait

Write-Host "User data script complete"
</powershell>
