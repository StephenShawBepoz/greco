<#
.SYNOPSIS
    Configure Network Settings

.DESCRIPTION
    Configures network settings for BEPOZ environment based on registry configuration.
    Demonstrates BEPOZCore module usage for system configuration tasks.

.NOTES
    Version: 1.0.1
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
    Requires Admin: Yes
#>

Write-BEPOZLog -Message "=== Configure Network Settings Script Started ===" -Level Info

try {
    Write-Host ""
    Write-Host "BEPOZ Network Configuration" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Retrieve network configuration from registry
    Write-Host "Reading network configuration from registry..." -ForegroundColor Yellow
    Write-BEPOZLog -Message "Reading network configuration from registry" -Level Info

    try {
        $dnsServer = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Network" -Name "DNSServer"
        $domainName = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Network" -Name "DomainName"
        $workgroupName = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Network" -Name "WorkgroupName"

        Write-Host "Configuration retrieved successfully." -ForegroundColor Green
        Write-BEPOZLog -Message "DNS Server: $dnsServer, Domain: $domainName, Workgroup: $workgroupName" -Level Info
    }
    catch {
        Write-Host "Warning: Could not read all settings from registry. Using defaults..." -ForegroundColor Yellow
        Write-BEPOZLog -Message "Registry read failed, using defaults: $_" -Level Warning

        $dnsServer = "8.8.8.8"
        $domainName = "bepoz.local"
        $workgroupName = "BEPOZ"
    }

    # Get active network adapters
    Write-Host ""
    Write-Host "Detecting network adapters..." -ForegroundColor Yellow

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Virtual*" }

    if ($adapters.Count -eq 0) {
        throw "No active network adapters found"
    }

    Write-Host "Found $($adapters.Count) active network adapter(s):" -ForegroundColor Green
    foreach ($adapter in $adapters) {
        Write-Host "  - $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor White
    }

    Write-BEPOZLog -Message "Found $($adapters.Count) active network adapters" -Level Info

    # Configure DNS for each adapter
    Write-Host ""
    Write-Host "Configuring DNS settings..." -ForegroundColor Yellow

    foreach ($adapter in $adapters) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServer -ErrorAction Stop
            Write-Host "  DNS configured for $($adapter.Name): $dnsServer" -ForegroundColor Green
            Write-BEPOZLog -Message "DNS configured for adapter $($adapter.Name): $dnsServer" -Level Success
        }
        catch {
            Write-Host "  Failed to configure DNS for $($adapter.Name): $_" -ForegroundColor Red
            Write-BEPOZLog -Message "DNS configuration failed for $($adapter.Name): $_" -Level Error
        }
    }

    # Set computer description
    Write-Host ""
    Write-Host "Setting computer description..." -ForegroundColor Yellow

    $computerName = $env:COMPUTERNAME
    $description = "BEPOZ Workstation - Configured $(Get-Date -Format 'yyyy-MM-dd')"

    try {
        # Get current computer system
        $computerSystem = Get-CimInstance -ClassName Win32_OperatingSystem
        $computerSystem | Set-CimInstance -Property @{Description = $description}

        Write-Host "Computer description set successfully." -ForegroundColor Green
        Write-BEPOZLog -Message "Computer description updated: $description" -Level Success
    }
    catch {
        Write-Host "Could not set computer description: $_" -ForegroundColor Yellow
        Write-BEPOZLog -Message "Failed to set computer description: $_" -Level Warning
    }

    # Query database for any additional network settings
    Write-Host ""
    Write-Host "Checking database for computer-specific settings..." -ForegroundColor Yellow

    try {
        $query = "SELECT * FROM NetworkSettings WHERE ComputerName = @ComputerName OR ComputerName = 'DEFAULT'"
        $settings = Invoke-BEPOZDatabaseQuery -Query $query -Parameters @{ ComputerName = $computerName }

        if ($settings.Rows.Count -gt 0) {
            Write-Host "Found $($settings.Rows.Count) network setting(s) in database." -ForegroundColor Green
            Write-BEPOZLog -Message "Applied $($settings.Rows.Count) settings from database" -Level Info
        }
        else {
            Write-Host "No computer-specific settings found." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "Could not query network settings from database: $_" -ForegroundColor Yellow
        Write-BEPOZLog -Message "Database query failed: $_" -Level Warning
    }

    # Log audit trail
    Write-BEPOZAudit -Action "Network Configuration" `
                     -Details "Network settings configured: DNS=$dnsServer, Domain=$domainName" `
                     -TargetUser ""

    # Display summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "Network Configuration Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Computer Name: " -NoNewline -ForegroundColor Yellow
    Write-Host $computerName -ForegroundColor White
    Write-Host "DNS Server:    " -NoNewline -ForegroundColor Yellow
    Write-Host $dnsServer -ForegroundColor White
    Write-Host "Domain:        " -NoNewline -ForegroundColor Yellow
    Write-Host $domainName -ForegroundColor White
    Write-Host "Workgroup:     " -NoNewline -ForegroundColor Yellow
    Write-Host $workgroupName -ForegroundColor White
    Write-Host ""
    Write-Host "Network adapters configured: $($adapters.Count)" -ForegroundColor White
    Write-Host ""

    Write-BEPOZLog -Message "Network configuration completed successfully" -Level Success
}
catch {
    Write-Host ""
    Write-Host "ERROR: Network configuration failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BEPOZLog -Message "Network configuration failed: $_" -Level Error
    Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
    throw
}

Write-BEPOZLog -Message "=== Configure Network Settings Script Ended ===" -Level Info
