# BEPOZ Deployment Framework - Developer Guide

This guide provides detailed instructions for developers who want to create new scripts for the BEPOZ Deployment Framework.

## Table of Contents

1. [Script Structure](#script-structure)
2. [Using BEPOZCore Functions](#using-bepozcore-functions)
3. [Script Best Practices](#script-best-practices)
4. [Updating the Manifest](#updating-the-manifest)
5. [Testing Your Scripts](#testing-your-scripts)
6. [Deployment Process](#deployment-process)

## Script Structure

### Basic Template

Every script should follow this structure:

```powershell
<#
.SYNOPSIS
    Brief one-line description of what the script does

.DESCRIPTION
    Detailed description of the script's functionality,
    requirements, and any important notes

.NOTES
    Version: 1.0.0
    Author: Your Name
    Last Updated: YYYY-MM-DD
    Requires Admin: Yes/No
#>

# BEPOZCore module is already imported by launcher
# All functions are available: Write-BEPOZLog, Invoke-BEPOZDatabaseQuery, etc.

Write-BEPOZLog -Message "=== Script Name Started ===" -Level Info

try {
    # Your script logic here

    Write-BEPOZLog -Message "Script completed successfully" -Level Success
}
catch {
    Write-Host ""
    Write-Host "ERROR: Script failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BEPOZLog -Message "Script failed: $_" -Level Error
    Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
    throw
}

Write-BEPOZLog -Message "=== Script Name Ended ===" -Level Info
```

### Required Elements

1. **Comment-Based Help**: Use `<# ... #>` block at the top
2. **Start Logging**: Log script start with `Write-BEPOZLog`
3. **Try-Catch Block**: Wrap main logic in try-catch
4. **Error Handling**: Log errors with stack traces
5. **End Logging**: Log script completion

## Using BEPOZCore Functions

### Write-BEPOZLog

Write log messages to console and log file.

```powershell
# Info message (white text)
Write-BEPOZLog -Message "Processing user data" -Level Info

# Success message (green text)
Write-BEPOZLog -Message "User created successfully" -Level Success

# Warning message (yellow text)
Write-BEPOZLog -Message "Could not find optional setting" -Level Warning

# Error message (red text)
Write-BEPOZLog -Message "Failed to connect to database" -Level Error
```

### Invoke-BEPOZDatabaseQuery

Execute SQL queries with parameterized values (prevents SQL injection).

```powershell
# Query with parameters
$query = "SELECT * FROM Users WHERE Status = @Status AND Department = @Dept"
$results = Invoke-BEPOZDatabaseQuery -Query $query -Parameters @{
    Status = "Active"
    Dept = "IT"
}

# Access results
foreach ($row in $results.Rows) {
    Write-Host "User: $($row.Username)"
}

# Insert query
$insertQuery = @"
INSERT INTO Users (Username, FirstName, LastName, CreatedDate)
VALUES (@Username, @FirstName, @LastName, GETDATE())
"@

Invoke-BEPOZDatabaseQuery -Query $insertQuery -Parameters @{
    Username = "jdoe"
    FirstName = "John"
    LastName = "Doe"
}
```

### Get-BEPOZRegistryValue

Read Windows Registry values safely.

```powershell
# Read registry value
$serverName = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Database" -Name "ServerName"

# Handle missing values with try-catch
try {
    $optionalValue = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Config" -Name "OptionalSetting"
}
catch {
    Write-BEPOZLog -Message "Optional setting not found, using default" -Level Warning
    $optionalValue = "DefaultValue"
}
```

### Write-BEPOZAudit

Log audit trail entries to database.

```powershell
# Log an audit entry
Write-BEPOZAudit -Action "User Created" `
                 -Details "Standard user account created for new employee" `
                 -TargetUser "jdoe"

# Audit entries include timestamp, computer name, and current user automatically
```

### Get-BEPOZDatabaseConfig

Get database connection info from registry.

```powershell
$config = Get-BEPOZDatabaseConfig
Write-Host "Server: $($config.ServerName)"
Write-Host "Database: $($config.DatabaseName)"
```

## Script Best Practices

### 1. User Input Validation

Always validate user input before processing:

```powershell
$username = Read-Host "Username"

# Validate not empty
if ([string]::IsNullOrWhiteSpace($username)) {
    throw "Username is required"
}

# Validate format
if ($username -notmatch '^[a-zA-Z0-9_]+$') {
    throw "Username can only contain letters, numbers, and underscores"
}
```

### 2. Check for Existing Resources

Verify resources don't already exist:

```powershell
# Check database
$query = "SELECT COUNT(*) as Count FROM Users WHERE Username = @Username"
$result = Invoke-BEPOZDatabaseQuery -Query $query -Parameters @{ Username = $username }

if ($result.Rows[0].Count -gt 0) {
    throw "User already exists"
}

# Check Windows account
try {
    Get-LocalUser -Name $username -ErrorAction Stop
    throw "Windows account already exists"
}
catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
    # Good - user doesn't exist
}
```

### 3. Provide Clear Feedback

Use colored output and clear messaging:

```powershell
Write-Host "Creating user account..." -ForegroundColor Yellow
# ... perform operation ...
Write-Host "User account created successfully!" -ForegroundColor Green

# Use separators for clarity
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   Operation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
```

### 4. Handle Errors Gracefully

Distinguish between fatal and non-fatal errors:

```powershell
# Fatal error - stop execution
if ($criticalConditionFailed) {
    Write-BEPOZLog -Message "Critical condition failed" -Level Error
    throw "Cannot continue"
}

# Non-fatal error - warn and continue
try {
    # Optional operation
}
catch {
    Write-BEPOZLog -Message "Optional operation failed: $_" -Level Warning
    Write-Host "Warning: Optional setting could not be applied" -ForegroundColor Yellow
    # Continue execution
}
```

### 5. Use Confirmation for Destructive Actions

```powershell
Write-Host "WARNING: This will delete all data!" -ForegroundColor Red
$confirm = Read-Host "Type 'yes' to confirm"

if ($confirm -ne "yes") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    Write-BEPOZLog -Message "Operation cancelled by user" -Level Info
    return
}
```

## Updating the Manifest

After creating a new script, add it to `manifest.json`:

### For Scripts in a Subcategory

```json
{
  "categories": [
    {
      "name": "User Management",
      "description": "User account operations",
      "subcategories": [
        {
          "name": "Account Creation",
          "tools": [
            {
              "name": "Create Standard User",
              "description": "Creates new standard user account",
              "scriptPath": "scripts/user-management/account-creation/CreateStandardUser.ps1",
              "version": "1.0.0",
              "lastUpdated": "2026-02-17T00:00:00Z",
              "documentationUrl": "https://docs.bepoz.com/users/create-standard",
              "requiresAdmin": true
            }
          ]
        }
      ]
    }
  ]
}
```

### For Scripts Directly in a Category

```json
{
  "categories": [
    {
      "name": "Reporting",
      "description": "Generate reports",
      "tools": [
        {
          "name": "Generate Onboarding Report",
          "description": "Creates comprehensive onboarding report",
          "scriptPath": "scripts/reporting/GenerateOnboardingReport.ps1",
          "version": "1.0.0",
          "lastUpdated": "2026-02-17T00:00:00Z",
          "documentationUrl": "",
          "requiresAdmin": false
        }
      ]
    }
  ]
}
```

### Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name shown in menu |
| `description` | Yes | Brief description of functionality |
| `scriptPath` | Yes | Relative path from repository root |
| `version` | Yes | Semantic version (major.minor.patch) |
| `lastUpdated` | Yes | ISO 8601 date string |
| `documentationUrl` | No | Link to detailed documentation (use "" if none) |
| `requiresAdmin` | Yes | Boolean - does script need admin rights |

## Testing Your Scripts

### 1. Local Testing

Test scripts locally before adding to framework:

```powershell
# Import BEPOZCore module
Import-Module .\modules\BEPOZCore.psm1

# Set up log file path
$global:BEPOZLogFile = "C:\Logs\BEPOZDeployment\test.log"
New-Item -Path "C:\Logs\BEPOZDeployment" -ItemType Directory -Force

# Run your script
.\scripts\user-management\CreateStandardUser.ps1
```

### 2. Development Branch Testing

1. Commit your script to the **development** branch
2. Update `manifest.json` in the **development** branch
3. Use `deploy-dev.bat` to test from GitHub
4. Verify:
   - Script appears in menu correctly
   - Script executes without errors
   - Logging works properly
   - Database operations succeed
   - Error handling works

### 3. Testing Checklist

- [ ] Script has proper comment-based help
- [ ] Logging statements at start and end
- [ ] All user input is validated
- [ ] Error handling covers all operations
- [ ] Database operations use parameterized queries
- [ ] Audit logging for important actions
- [ ] Clear user feedback during execution
- [ ] Cleanup of temporary resources
- [ ] Works with and without admin rights (if applicable)
- [ ] Manifest entry is correct

## Deployment Process

### Workflow: Development → Production

1. **Develop in Development Branch**
   ```bash
   git checkout development
   # Create/modify your script
   git add scripts/your-script.ps1
   git commit -m "Add new script: Your Script"
   git push origin development
   ```

2. **Update Manifest**
   ```bash
   # Still on development branch
   # Edit manifest.json
   git add manifest.json
   git commit -m "Add Your Script to manifest"
   git push origin development
   ```

3. **Test with deploy-dev.bat**
   - Run `deploy-dev.bat` on a test machine
   - Verify script works correctly
   - Check logs for any issues

4. **Promote to Production**
   ```bash
   # Merge to main branch
   git checkout main
   git merge development
   git push origin main
   ```

5. **Verify in Production**
   - Run `deploy-main.bat` on a test machine
   - Confirm script is available and works
   - Script is now live for all technicians

### Version Numbering

Follow semantic versioning:

- **Major** (1.0.0 → 2.0.0): Breaking changes, major rewrites
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes, minor improvements

Update both:
- Script comment header: `Version: 1.0.1`
- Manifest entry: `"version": "1.0.1"`
- Manifest entry: `"lastUpdated": "2026-02-17T00:00:00Z"`

## Example: Complete Script Development

Let's create a complete example of adding a new script:

### Step 1: Create the Script

`scripts/user-management/account-modification/DisableUser.ps1`

```powershell
<#
.SYNOPSIS
    Disable User Account

.DESCRIPTION
    Disables a user account in both Windows and BEPOZ database.
    Account can be re-enabled later.

.NOTES
    Version: 1.0.0
    Author: IT Team
    Last Updated: 2026-02-17
    Requires Admin: Yes
#>

Write-BEPOZLog -Message "=== Disable User Account Script Started ===" -Level Info

try {
    Write-Host ""
    Write-Host "Disable User Account" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Get username
    $username = Read-Host "Username to disable"

    if ([string]::IsNullOrWhiteSpace($username)) {
        throw "Username is required"
    }

    Write-BEPOZLog -Message "Disabling user: $username" -Level Info

    # Check if user exists in database
    $query = "SELECT Status FROM Users WHERE Username = @Username"
    $result = Invoke-BEPOZDatabaseQuery -Query $query -Parameters @{ Username = $username }

    if ($result.Rows.Count -eq 0) {
        throw "User '$username' not found in database"
    }

    if ($result.Rows[0].Status -eq "Disabled") {
        Write-Host "User is already disabled" -ForegroundColor Yellow
        return
    }

    # Confirm action
    Write-Host ""
    Write-Host "WARNING: This will disable the user account!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to confirm"

    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        Write-BEPOZLog -Message "User disable cancelled" -Level Info
        return
    }

    # Disable Windows account
    Write-Host "Disabling Windows account..." -ForegroundColor Yellow
    Disable-LocalUser -Name $username -ErrorAction Stop
    Write-Host "Windows account disabled" -ForegroundColor Green
    Write-BEPOZLog -Message "Windows account disabled: $username" -Level Success

    # Update database
    Write-Host "Updating database..." -ForegroundColor Yellow
    $updateQuery = "UPDATE Users SET Status = 'Disabled', DisabledDate = GETDATE(), DisabledBy = @DisabledBy WHERE Username = @Username"
    Invoke-BEPOZDatabaseQuery -Query $updateQuery -Parameters @{
        Username = $username
        DisabledBy = $env:USERNAME
    }

    Write-Host "Database updated" -ForegroundColor Green
    Write-BEPOZLog -Message "Database updated for user: $username" -Level Success

    # Log audit
    Write-BEPOZAudit -Action "User Account Disabled" `
                     -Details "User account disabled" `
                     -TargetUser $username

    Write-Host ""
    Write-Host "User account disabled successfully!" -ForegroundColor Green
    Write-BEPOZLog -Message "User disable completed successfully" -Level Success
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to disable user" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BEPOZLog -Message "User disable failed: $_" -Level Error
    Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
    throw
}

Write-BEPOZLog -Message "=== Disable User Account Script Ended ===" -Level Info
```

### Step 2: Update Manifest

Add to the "Account Modification" subcategory in `manifest.json`:

```json
{
  "name": "Disable User Account",
  "description": "Disables a user account (can be re-enabled later)",
  "scriptPath": "scripts/user-management/account-modification/DisableUser.ps1",
  "version": "1.0.0",
  "lastUpdated": "2026-02-17T00:00:00Z",
  "documentationUrl": "",
  "requiresAdmin": true
}
```

### Step 3: Test and Deploy

```bash
# Commit to development
git checkout development
git add scripts/user-management/account-modification/DisableUser.ps1
git add manifest.json
git commit -m "Add DisableUser script"
git push origin development

# Test with deploy-dev.bat

# If successful, merge to main
git checkout main
git merge development
git push origin main
```

## Summary

1. Follow the script template structure
2. Use BEPOZCore functions for all operations
3. Validate input and handle errors gracefully
4. Provide clear user feedback
5. Update manifest.json with correct metadata
6. Test in development branch first
7. Promote to main branch for production

For questions or issues, contact the BEPOZ IT Team.
