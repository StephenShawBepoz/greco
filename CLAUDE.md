# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BEPOZ Deployment Framework - A self-updating PowerShell deployment system for IT technicians to remotely execute onboarding scripts on BEPOZ computers via ScreenConnect. Scripts are downloaded fresh from GitHub on every execution (ephemeral architecture), ensuring no stale code.

## Architecture

### Three-Tier Bootstrap System
1. **Bootstrap Layer**: BAT files (`deploy-main.bat` or `deploy-dev.bat`) contain GitHub PAT and download launcher
2. **Launcher Layer**: `launcher.ps1` downloads manifest, presents interactive menu, downloads and executes selected scripts
3. **Execution Layer**: Individual scripts in `scripts/` directory, organized by category, utilizing `BEPOZCore.psm1` module

### Key Design Principles
- **Ephemeral Execution**: Scripts downloaded fresh on every run, deleted after execution
- **Fail-Fast**: GitHub connectivity failures produce clear error messages, no fallback behavior
- **Registry-Driven Config**: All BEPOZ configuration (database, network settings) retrieved from Windows Registry at `HKLM:\SOFTWARE\BEPOZ\`
- **Single Responsibility**: Core utilities (database, registry, logging) centralized in `BEPOZCore.psm1`

## Branch Strategy

- **main**: Production-ready, stable scripts (deploy via `deploy-main.bat`)
- **development**: Testing and development (deploy via `deploy-dev.bat`)

Always test new scripts or changes in development branch before merging to main.

## Core Modules

### BepozDbCore (`modules/BepozDbCore.ps1`)
Production-ready database access with registry-based discovery.
- **Registry**: `HKCU:\SOFTWARE\Backoffice` (SQL_Server, SQL_DSN)
- **Functions**:
  - `Get-BepozDatabaseConfig` - Retrieves DB config from registry
  - `Get-BepozConnectionString` - Builds connection string
  - `Invoke-BepozQuery` - Executes SELECT queries, returns DataTable
  - `Invoke-BepozNonQuery` - Executes INSERT/UPDATE/DELETE, returns row count
  - `Invoke-BepozStoredProc` - Executes stored procedures
  - `Test-BepozDatabaseConnection` - Tests connectivity
  - `Get-BepozDbInfo` - Comprehensive database information

### BepozLogger (`modules/BepozLogger.ps1`)
Centralized logging with automatic rotation and performance tracking.
- **Log Location**: `C:\Bepoz\Toolkit\Logs\` (30-day retention)
- **Functions**:
  - `Initialize-BepozLogger` - Initializes logging for a tool
  - `Write-BepozLog` - Writes log entries (INFO, WARN, ERROR, SUCCESS, ACTION, QUERY, PERF)
  - `Write-BepozLogAction` - Logs user actions
  - `Write-BepozLogQuery` - Logs SQL queries with performance metrics
  - `Write-BepozLogPerformance` - Logs operation performance
  - `Write-BepozLogError` - Logs errors with stack traces
  - `Measure-BepozOperation` - Measures and logs operation timing

### BepozTheme (`modules/BepozTheme.ps1`)
Official Bepoz brand UI theming for Windows Forms.
- **Colors**: Primary Blue (#002D6A), Dark Blue, Purple, Green, Gray, Light Blue
- **Functions**: Create themed controls (buttons, panels, forms, grids, labels, textboxes)
- **Key Functions**:
  - `New-BepozForm`, `New-BepozButton`, `New-BepozPanel`
  - `New-BepozDataGridView`, `New-BepozLabel`, `New-BepozTextBox`
  - `Apply-BepozFormTheme` - Apply theme to entire form
  - `Get-BepozColor`, `Get-BepozFont` - Color and font helpers

### BepozUI (`modules/BepozUI.ps1`)
Common Windows Forms UI helpers (reduces GUI code by 30-40%).
- **Functions**:
  - `Show-BepozProgressDialog`, `Update-BepozProgressDialog` - Progress indicators
  - `Show-BepozInputDialog`, `Show-BepozNumberDialog`, `Show-BepozDropdownDialog` - Input dialogs
  - `Show-BepozFilePicker`, `Show-BepozFolderPicker` - File/folder selection
  - `Show-BepozConfirmDialog`, `Show-BepozMessageBox` - Confirmations and alerts
  - `Show-BepozDataGrid` - Display DataTable in sortable grid

### Manifest (`manifest.json`)
Central registry of all scripts with metadata. Structure:
- Categories (can have subcategories or tools directly)
- Subcategories (contain tools)
- Tools: name, description, scriptPath, version, lastUpdated, documentationUrl, requiresAdmin

### Launcher (`launcher.ps1`)
Parameters: `-GitHubPAT`, `-RepoOwner`, `-RepoName`, `-Branch`
Execution flow: Download all modules (Logger, DbCore, Theme, UI) → Import in order → Initialize logger → Download manifest → Display menu → Execute selected script → Cleanup

## Required Script Structure

All scripts MUST follow this template:

```powershell
<#
.SYNOPSIS
    Brief one-line description
.DESCRIPTION
    Detailed functionality description
.NOTES
    Version: X.Y.Z
    Author: Name
    Last Updated: YYYY-MM-DD
    Requires Admin: Yes/No
#>

Write-BepozLog -Message "=== Script Name Started ===" -Level INFO

try {
    # Script logic here
    # Bepoz modules already imported - all functions available

    Write-BepozLog -Message "Script completed successfully" -Level SUCCESS
}
catch {
    Write-Host ""
    Write-Host "ERROR: Script failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BepozLog -Message "Script failed: $_" -Level ERROR
    Write-BepozLog -Message $_.ScriptStackTrace -Level ERROR
    throw
}

Write-BepozLog -Message "=== Script Name Ended ===" -Level INFO
```

## Adding New Scripts

1. **Create Script File**: Place in appropriate category under `scripts/` following directory structure
2. **Follow Template**: Use required script structure above
3. **Use BEPOZCore Functions**: For all database, registry, and logging operations
4. **Update Manifest**: Add entry to `manifest.json` with complete metadata:
   - name, description, scriptPath (relative to repo root)
   - version, lastUpdated (ISO 8601 format)
   - requiresAdmin (boolean)
   - documentationUrl (optional)
5. **Test**: Use `deploy-dev.bat` to test from development branch
6. **Merge**: After testing, merge to main branch for production availability

## Configuration Requirements

### Registry Paths (Expected by Scripts)
```
HKCU:\SOFTWARE\Backoffice
  - SQL_Server: SQL Server instance name
  - SQL_DSN: BEPOZ database name

HKLM:\SOFTWARE\BEPOZ\Network
  - DNSServer, DomainName, WorkgroupName

HKLM:\SOFTWARE\BEPOZ\Users
  - DefaultHomeDrive, DefaultProfilePath
```

### Database Tables (Expected by Framework)
- `Users`: User account information
- `AuditLog`: Audit trail logging
- `NetworkSettings`: Computer-specific network settings

## Logging

- **Location**: `C:\Bepoz\Toolkit\Logs\`
- **Naming**: `ToolName_YYYYMMDD.log`
- **Format**: `[timestamp] [user] [LEVEL] message`
- **Levels**: INFO, WARN, ERROR, SUCCESS, ACTION, QUERY, PERF
- **Retention**: 30 days (automatic cleanup)
- **Features**: Millisecond precision, performance tracking, query logging

## Testing Framework

Run launcher locally for testing:
```powershell
.\launcher.ps1 -GitHubPAT "ghp_xxxxx" -RepoOwner "YourOrg" -RepoName "BEPOZ-Scripts" -Branch "development"
```

Test individual scripts by importing modules manually:
```powershell
Import-Module .\modules\BepozLogger.ps1
Import-Module .\modules\BepozDbCore.ps1
Import-Module .\modules\BepozTheme.ps1
Import-Module .\modules\BepozUI.ps1
Initialize-BepozLogger -ToolName "TestScript"
.\scripts\path-to-script.ps1
```

## Security Considerations

- GitHub PAT stored ONLY in BAT files (not in repository)
- PAT should have minimal scope (repo read access only)
- Private repository prevents unauthorized script access
- Database uses Windows Integrated Security (no hardcoded credentials)
- Logs may contain sensitive information - restrict permissions
- Never commit BAT files with actual PAT tokens

## File Organization

```
greco/
├── launcher.ps1              # Main orchestrator
├── manifest.json             # Script registry
├── deploy-main.bat          # Production bootstrap (main branch)
├── deploy-dev.bat           # Development bootstrap (development branch)
├── modules/
│   ├── BepozDbCore.ps1     # Database access functions
│   ├── BepozLogger.ps1     # Logging with rotation
│   ├── BepozTheme.ps1      # UI theming (official colors)
│   └── BepozUI.ps1         # UI helper dialogs
├── scripts/                 # Organized by category
│   ├── user-management/
│   │   ├── account-creation/
│   │   └── account-modification/
│   ├── system-configuration/
│   └── reporting/
├── docs/
│   ├── developer-guide.md
│   └── troubleshooting.md
└── tests/                   # Future: Pester tests
```

## Important Notes

- **NO** traditional build process - scripts execute directly
- **NO** package manager (npm/pip/etc) - pure PowerShell
- Scripts are **never** cached locally by design
- Launcher creates temporary directory `%TEMP%\BEPOZDeployment_*`, cleans up automatically
- All scripts receive `$global:BEPOZLogFile` variable from launcher
- BAT files use `EnableDelayedExpansion` for proper variable handling
- PowerShell execution with `-ExecutionPolicy Bypass` required

## Common Patterns

### Database Query with Parameters
```powershell
$query = "SELECT * FROM Users WHERE Status = @Status"
$results = Invoke-BepozQuery -Query $query -Parameters @{ Status = "Active" }
foreach ($row in $results.Rows) {
    Write-Host $row.Username
}
```

### Stored Procedure Execution
```powershell
$params = @{ "@VenueID" = 1 }
$results = Invoke-BepozStoredProc -ProcedureName "dbo.GetVenueDetails" -Parameters $params
```

### Action Logging
```powershell
Write-BepozLogAction -Action "User created: jdoe"
Write-BepozLogQuery -Query $sql -DurationMs 45 -RowCount 12
```

### UI Dialogs
```powershell
# Input dialog
$name = Show-BepozInputDialog -Title "Name" -Prompt "Enter workstation name:"

# Confirmation
if (Show-BepozConfirmDialog -Title "Confirm" -Message "Delete records?") {
    # User clicked Yes
}

# Data grid
$data = Invoke-BepozQuery -Query "SELECT * FROM Venue"
Show-BepozDataGrid -Title "Venues" -Data $data
```

## Troubleshooting

- **"Failed to download launcher"**: Check internet, GitHub PAT validity, repo access
- **"Cannot continue without module"**: Verify all 4 modules exist in `modules/` directory
- **"Registry path not found"**: Ensure BEPOZ is installed and registry configured
- **Logs**: Always check `C:\Logs\BEPOZDeployment\` for detailed error information
