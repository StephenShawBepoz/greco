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

## Core Components

### BEPOZCore Module (`modules/BEPOZCore.psm1`)
Provides six core functions available to all scripts:
- `Get-BEPOZDatabaseConfig` - Retrieves DB config from registry
- `New-BEPOZDatabaseConnection` - Creates SQL connection
- `Invoke-BEPOZDatabaseQuery` - Executes parameterized SQL queries
- `Get-BEPOZRegistryValue` - Reads Windows Registry values
- `Write-BEPOZLog` - Writes formatted log entries (console + file)
- `Write-BEPOZAudit` - Logs audit trail to database

### Manifest (`manifest.json`)
Central registry of all scripts with metadata. Structure:
- Categories (can have subcategories or tools directly)
- Subcategories (contain tools)
- Tools: name, description, scriptPath, version, lastUpdated, documentationUrl, requiresAdmin

### Launcher (`launcher.ps1`)
Parameters: `-GitHubPAT`, `-RepoOwner`, `-RepoName`, `-Branch`
Execution flow: Download core module → Import module → Download manifest → Display menu → Execute selected script → Cleanup

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

Write-BEPOZLog -Message "=== Script Name Started ===" -Level Info

try {
    # Script logic here
    # BEPOZCore module already imported - all functions available

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
HKLM:\SOFTWARE\BEPOZ\Database
  - ServerName: SQL Server instance
  - DatabaseName: BEPOZ database name

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

- **Location**: `C:\Logs\BEPOZDeployment\`
- **Naming**: `YYYYMMDD_HHmmss_ScriptName.log`
- **Format**: `[timestamp] [Level] [COMPUTER\user] message`
- **Levels**: Info (white), Success (green), Warning (yellow), Error (red)

## Testing Framework

Run launcher locally for testing:
```powershell
.\launcher.ps1 -GitHubPAT "ghp_xxxxx" -RepoOwner "YourOrg" -RepoName "BEPOZ-Scripts" -Branch "development"
```

Test individual scripts by importing module manually:
```powershell
Import-Module .\modules\BEPOZCore.psm1
$global:BEPOZLogFile = "C:\Logs\BEPOZDeployment\test.log"
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
│   └── BEPOZCore.psm1      # Core utilities module
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
$results = Invoke-BEPOZDatabaseQuery -Query $query -Parameters @{ Status = "Active" }
foreach ($row in $results.Rows) {
    Write-Host $row.Username
}
```

### Registry Value Retrieval
```powershell
$value = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Config" -Name "Setting"
```

### Audit Logging
```powershell
Write-BEPOZAudit -Action "User Created" -Details "Standard user account" -TargetUser "jdoe"
```

## Troubleshooting

- **"Failed to download launcher"**: Check internet, GitHub PAT validity, repo access
- **"Cannot continue without core module"**: Verify `modules/BEPOZCore.psm1` exists
- **"Registry path not found"**: Ensure BEPOZ is installed and registry configured
- **Logs**: Always check `C:\Logs\BEPOZDeployment\` for detailed error information
