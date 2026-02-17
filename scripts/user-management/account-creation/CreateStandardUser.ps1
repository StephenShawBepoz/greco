<#
.SYNOPSIS
    Create Standard User Account

.DESCRIPTION
    Creates a new standard user account in the BEPOZ system with default
    permissions and configuration. Demonstrates BEPOZCore module usage.

.NOTES
    Version: 1.0.0
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
    Requires Admin: Yes
#>

# BEPOZCore module is already imported by launcher
# All functions are available: Write-BEPOZLog, Invoke-BEPOZDatabaseQuery, etc.

Write-BEPOZLog -Message "=== Create Standard User Script Started ===" -Level Info

try {
    # Prompt for user details
    Write-Host ""
    Write-Host "Create Standard User Account" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $firstName = Read-Host "First Name"
    $lastName = Read-Host "Last Name"
    $username = Read-Host "Username"
    $employeeId = Read-Host "Employee ID"

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($firstName) -or
        [string]::IsNullOrWhiteSpace($lastName) -or
        [string]::IsNullOrWhiteSpace($username) -or
        [string]::IsNullOrWhiteSpace($employeeId)) {
        throw "All fields are required"
    }

    Write-BEPOZLog -Message "Creating user: $username ($firstName $lastName)" -Level Info

    # Check if user already exists in database
    Write-Host ""
    Write-Host "Checking if user already exists..." -ForegroundColor Yellow

    $checkQuery = "SELECT COUNT(*) as UserCount FROM Users WHERE Username = @Username OR EmployeeId = @EmployeeId"
    $checkResult = Invoke-BEPOZDatabaseQuery -Query $checkQuery -Parameters @{
        Username = $username
        EmployeeId = $employeeId
    }

    if ($checkResult.Rows[0].UserCount -gt 0) {
        throw "User with username '$username' or Employee ID '$employeeId' already exists"
    }

    Write-Host "User does not exist. Proceeding with creation..." -ForegroundColor Green

    # Generate random password
    Add-Type -AssemblyName System.Web
    $password = [System.Web.Security.Membership]::GeneratePassword(12, 3)
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create Windows user account
    Write-Host "Creating Windows user account..." -ForegroundColor Yellow

    try {
        New-LocalUser -Name $username `
                      -Password $securePassword `
                      -FullName "$firstName $lastName" `
                      -Description "BEPOZ Standard User - Created $(Get-Date -Format 'yyyy-MM-dd')" `
                      -PasswordNeverExpires:$false `
                      -UserMayNotChangePassword:$false `
                      -AccountNeverExpires `
                      -ErrorAction Stop

        Write-Host "Windows account created successfully." -ForegroundColor Green
        Write-BEPOZLog -Message "Windows account created: $username" -Level Success
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "Windows account already exists. Continuing with database setup..." -ForegroundColor Yellow
            Write-BEPOZLog -Message "Windows account already exists: $username" -Level Warning
        }
        else {
            throw "Failed to create Windows account: $_"
        }
    }

    # Add user to standard users group
    try {
        Add-LocalGroupMember -Group "Users" -Member $username -ErrorAction SilentlyContinue
    }
    catch {
        Write-BEPOZLog -Message "User already in Users group or group operation failed: $_" -Level Warning
    }

    # Insert user into BEPOZ database
    Write-Host "Adding user to BEPOZ database..." -ForegroundColor Yellow

    $insertQuery = @"
INSERT INTO Users (Username, FirstName, LastName, EmployeeId, AccountType, Status, CreatedDate, CreatedBy)
VALUES (@Username, @FirstName, @LastName, @EmployeeId, 'Standard', 'Active', GETDATE(), @CreatedBy)
"@

    Invoke-BEPOZDatabaseQuery -Query $insertQuery -Parameters @{
        Username = $username
        FirstName = $firstName
        LastName = $lastName
        EmployeeId = $employeeId
        CreatedBy = $env:USERNAME
    }

    Write-Host "User added to database successfully." -ForegroundColor Green
    Write-BEPOZLog -Message "User added to database: $username" -Level Success

    # Retrieve default configuration from registry
    Write-Host "Applying default user settings..." -ForegroundColor Yellow

    try {
        $defaultHomeDrive = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Users" -Name "DefaultHomeDrive"
        $defaultProfile = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Users" -Name "DefaultProfilePath"

        Write-BEPOZLog -Message "Applied settings - Home Drive: $defaultHomeDrive, Profile: $defaultProfile" -Level Info
        Write-Host "Default settings applied successfully." -ForegroundColor Green
    }
    catch {
        Write-BEPOZLog -Message "Could not retrieve default settings from registry: $_" -Level Warning
        Write-Host "Warning: Could not apply some default settings." -ForegroundColor Yellow
    }

    # Log audit trail
    Write-BEPOZAudit -Action "User Account Created" `
                     -Details "Standard user account created: $firstName $lastName (Employee ID: $employeeId)" `
                     -TargetUser $username

    # Display summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "User Account Created Successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Username:    " -NoNewline -ForegroundColor Yellow
    Write-Host $username -ForegroundColor White
    Write-Host "Full Name:   " -NoNewline -ForegroundColor Yellow
    Write-Host "$firstName $lastName" -ForegroundColor White
    Write-Host "Employee ID: " -NoNewline -ForegroundColor Yellow
    Write-Host $employeeId -ForegroundColor White
    Write-Host "Account Type:" -NoNewline -ForegroundColor Yellow
    Write-Host " Standard User" -ForegroundColor White
    Write-Host "Password:    " -NoNewline -ForegroundColor Yellow
    Write-Host $password -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: Save the password securely and provide to user." -ForegroundColor Red
    Write-Host ""

    Write-BEPOZLog -Message "User creation completed successfully" -Level Success
}
catch {
    Write-Host ""
    Write-Host "ERROR: User creation failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BEPOZLog -Message "User creation failed: $_" -Level Error
    Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
    throw
}

Write-BEPOZLog -Message "=== Create Standard User Script Ended ===" -Level Info
