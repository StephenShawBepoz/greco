<#
.SYNOPSIS
    Create Administrator User Account

.DESCRIPTION
    Creates a new administrator user account in the BEPOZ system with elevated
    privileges. Demonstrates BEPOZCore module usage for admin account creation.

.NOTES
    Version: 1.0.0
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
    Requires Admin: Yes
#>

Write-BEPOZLog -Message "=== Create Administrator User Script Started ===" -Level Info

try {
    # Prompt for user details
    Write-Host ""
    Write-Host "Create Administrator User Account" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "WARNING: This will create an account with administrative privileges!" -ForegroundColor Red
    Write-Host ""

    $firstName = Read-Host "First Name"
    $lastName = Read-Host "Last Name"
    $username = Read-Host "Username (recommend 'admin_' prefix)"
    $employeeId = Read-Host "Employee ID"

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($firstName) -or
        [string]::IsNullOrWhiteSpace($lastName) -or
        [string]::IsNullOrWhiteSpace($username) -or
        [string]::IsNullOrWhiteSpace($employeeId)) {
        throw "All fields are required"
    }

    Write-BEPOZLog -Message "Creating administrator: $username ($firstName $lastName)" -Level Info

    # Confirm admin creation
    Write-Host ""
    $confirm = Read-Host "Create ADMINISTRATOR account for '$username'? (yes/NO)"
    if ($confirm -ne "yes") {
        Write-Host "Administrator account creation cancelled." -ForegroundColor Yellow
        Write-BEPOZLog -Message "Administrator account creation cancelled by user" -Level Info
        return
    }

    # Check if user already exists
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

    # Generate strong password for admin account
    Add-Type -AssemblyName System.Web
    $password = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create Windows user account
    Write-Host "Creating Windows administrator account..." -ForegroundColor Yellow

    try {
        New-LocalUser -Name $username `
                      -Password $securePassword `
                      -FullName "$firstName $lastName (Administrator)" `
                      -Description "BEPOZ Administrator - Created $(Get-Date -Format 'yyyy-MM-dd')" `
                      -PasswordNeverExpires:$false `
                      -UserMayNotChangePassword:$false `
                      -AccountNeverExpires `
                      -ErrorAction Stop

        Write-Host "Windows account created successfully." -ForegroundColor Green
        Write-BEPOZLog -Message "Windows administrator account created: $username" -Level Success
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "Windows account already exists. Continuing with setup..." -ForegroundColor Yellow
            Write-BEPOZLog -Message "Windows account already exists: $username" -Level Warning
        }
        else {
            throw "Failed to create Windows account: $_"
        }
    }

    # Add user to Administrators group
    Write-Host "Adding user to Administrators group..." -ForegroundColor Yellow
    try {
        Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Stop
        Write-Host "User added to Administrators group." -ForegroundColor Green
        Write-BEPOZLog -Message "User added to Administrators group: $username" -Level Success
    }
    catch {
        Write-BEPOZLog -Message "Failed to add to Administrators group: $_" -Level Warning
        Write-Host "Warning: Could not add user to Administrators group." -ForegroundColor Yellow
    }

    # Insert user into BEPOZ database
    Write-Host "Adding administrator to BEPOZ database..." -ForegroundColor Yellow

    $insertQuery = @"
INSERT INTO Users (Username, FirstName, LastName, EmployeeId, AccountType, Status, CreatedDate, CreatedBy)
VALUES (@Username, @FirstName, @LastName, @EmployeeId, 'Administrator', 'Active', GETDATE(), @CreatedBy)
"@

    Invoke-BEPOZDatabaseQuery -Query $insertQuery -Parameters @{
        Username = $username
        FirstName = $firstName
        LastName = $lastName
        EmployeeId = $employeeId
        CreatedBy = $env:USERNAME
    }

    Write-Host "Administrator added to database successfully." -ForegroundColor Green
    Write-BEPOZLog -Message "Administrator added to database: $username" -Level Success

    # Log audit trail
    Write-BEPOZAudit -Action "Administrator Account Created" `
                     -Details "Administrator account created: $firstName $lastName (Employee ID: $employeeId)" `
                     -TargetUser $username

    # Display summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "Administrator Account Created Successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Username:    " -NoNewline -ForegroundColor Yellow
    Write-Host $username -ForegroundColor White
    Write-Host "Full Name:   " -NoNewline -ForegroundColor Yellow
    Write-Host "$firstName $lastName" -ForegroundColor White
    Write-Host "Employee ID: " -NoNewline -ForegroundColor Yellow
    Write-Host $employeeId -ForegroundColor White
    Write-Host "Account Type:" -NoNewline -ForegroundColor Yellow
    Write-Host " Administrator" -ForegroundColor Red
    Write-Host "Password:    " -NoNewline -ForegroundColor Yellow
    Write-Host $password -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CRITICAL: Save this password securely!" -ForegroundColor Red
    Write-Host "This account has full administrative privileges." -ForegroundColor Red
    Write-Host ""

    Write-BEPOZLog -Message "Administrator creation completed successfully" -Level Success
}
catch {
    Write-Host ""
    Write-Host "ERROR: Administrator creation failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BEPOZLog -Message "Administrator creation failed: $_" -Level Error
    Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
    throw
}

Write-BEPOZLog -Message "=== Create Administrator User Script Ended ===" -Level Info
