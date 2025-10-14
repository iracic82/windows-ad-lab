<powershell>
$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\userdata_client.log" -Append

Write-Host "==== Starting Client Userdata Configuration ===="
Write-Host "Computer Name: ${computer_name}"

# Wait for network stack to initialize
Write-Host "Waiting for network to initialize..."
Start-Sleep -Seconds 30

# Set Administrator password
Write-Host "Setting Administrator password..."
try {
    $AdminPassword = ConvertTo-SecureString "${domain_admin_password}" -AsPlainText -Force
    Set-LocalUser -Name "Administrator" -Password $AdminPassword
    Set-LocalUser -Name "Administrator" -PasswordNeverExpires $true
    Write-Host "Administrator password set successfully"
} catch {
    Write-Host "ERROR: Failed to set admin password: $_"
}

# Set hostname
Write-Host "Setting computer name to: ${computer_name}"
try {
    Rename-Computer -NewName "${computer_name}" -Force -ErrorAction Stop
    Write-Host "Hostname set to ${computer_name}"
} catch {
    Write-Host "ERROR: Failed to set hostname: $_"
}

# Set DNS to point to DC1
Write-Host "Setting DNS to DC1: ${dc1_ip}"
try {
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "${dc1_ip}"
        Write-Host "DNS set to ${dc1_ip} on adapter: $($adapter.Name)"
    }
} catch {
    Write-Host "ERROR: DNS configuration failed: $_"
}

# Configure WinRM
Write-Host "Configuring WinRM..."
try {
    winrm quickconfig -force
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "WinRM configured successfully"
} catch {
    Write-Host "ERROR: WinRM setup failed: $_"
}

# Create firewall rules
Write-Host "Creating firewall rules..."
$firewallRules = @(
    @{ Name = "WinRM-HTTP";  Port = 5985 },
    @{ Name = "WinRM-HTTPS"; Port = 5986 },
    @{ Name = "RDP";         Port = 3389 }
)
foreach ($rule in $firewallRules) {
    try {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $rule.Port -ErrorAction SilentlyContinue
        Write-Host "Created firewall rule: $($rule.Name) on port $($rule.Port)"
    } catch {
        Write-Host "ERROR: Failed to create firewall rule for $($rule.Port): $_"
    }
}

# Enable RDP
Write-Host "Enabling RDP..."
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Write-Host "RDP enabled"
} catch {
    Write-Host "ERROR: RDP configuration failed: $_"
}

# Disable Windows Firewall temporarily
Write-Host "Temporarily disabling Windows Firewall..."
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Write-Host "Firewall disabled"
} catch {
    Write-Host "ERROR: Failed to disable firewall: $_"
}

# Set timezone
Write-Host "Setting timezone to UTC..."
try {
    Set-TimeZone -Id "UTC" -ErrorAction Stop
    Write-Host "Timezone set to UTC"
} catch {
    Write-Host "ERROR: Failed to set timezone: $_"
}

# Restart WinRM service
Write-Host "Restarting WinRM service..."
try {
    Restart-Service winrm -Force
    Write-Host "WinRM service restarted"
} catch {
    Write-Host "ERROR: WinRM restart failed: $_"
}

Write-Host "==== Client Userdata Configuration Completed ===="
Write-Host "Rebooting in 30 seconds to apply hostname change..."
Stop-Transcript

# Reboot to apply computer name
shutdown /r /t 30 /c "Rebooting to apply client configuration"
</powershell>
