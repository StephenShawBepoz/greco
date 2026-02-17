# BEPOZ Deployment Framework

A self-updating PowerShell deployment framework for streamlining BEPOZ onboarding processes. This framework enables IT technicians to remotely execute onboarding scripts on BEPOZ computers via ScreenConnect with a single-click deployment model.

## Features

- **One-Click Deployment**: Launch via ScreenConnect toolbox with a single click
- **Always Fresh**: Scripts are downloaded fresh on every execution - no stale code
- **Interactive Menu**: Easy-to-use categorized menu for script selection
- **Version Control**: All scripts stored in private GitHub repository
- **Centralized Utilities**: Core module for database, registry, and logging operations
- **Comprehensive Logging**: All execution logged to local files for troubleshooting
- **Metadata Tracking**: Version numbers, update dates, and documentation links

## Quick Start

### Prerequisites

- Windows 10/11 with PowerShell 5.1+
- GitHub Personal Access Token with `repo` scope
- Private GitHub repository
- ScreenConnect for remote management (optional but recommended)

### Installation

1. **Create GitHub Repository**
   ```bash
   # Clone or create a new private repository
   git clone https://github.com/YourOrg/BEPOZ-Scripts.git
   ```

2. **Configure Deployment Scripts**
   - Edit `deploy-main.bat` for production deployment (main branch)
   - Edit `deploy-dev.bat` for testing deployment (development branch)
   - Replace `ghp_PASTE_YOUR_TOKEN_HERE` with your GitHub Personal Access Token
   - Update `REPO_OWNER` and `REPO_NAME` with your repository details

3. **Upload to ScreenConnect**
   - Upload `deploy-main.bat` to your ScreenConnect toolbox
   - Optionally upload `deploy-dev.bat` for testing

4. **Test the Framework**
   - Double-click `deploy-main.bat` on a test machine
   - Verify the menu loads and scripts execute correctly

## Repository Structure

```
BEPOZ-Scripts/
├── launcher.ps1              # Main orchestrator
├── manifest.json             # Script registry with metadata
├── deploy.bat                # Generic bootstrap (deprecated - use deploy-main.bat or deploy-dev.bat)
├── deploy-main.bat           # Production deployment (main branch)
├── deploy-dev.bat            # Development deployment (development branch)
├── README.md                 # This file
├── modules/
│   └── BEPOZCore.psm1       # Core utilities module
├── scripts/
│   ├── user-management/
│   │   ├── account-creation/
│   │   │   ├── CreateStandardUser.ps1
│   │   │   └── CreateAdminUser.ps1
│   │   └── account-modification/
│   │       └── ResetPassword.ps1
│   ├── system-configuration/
│   │   ├── ConfigureNetwork.ps1
│   │   └── InstallSoftware.ps1
│   └── reporting/
│       └── GenerateOnboardingReport.ps1
├── docs/
│   ├── developer-guide.md
│   └── troubleshooting.md
└── tests/
    └── BEPOZCore.Tests.ps1
```

## How It Works

### Execution Flow

1. Technician clicks `deploy-main.bat` or `deploy-dev.bat` in ScreenConnect
2. BAT file downloads `launcher.ps1` from GitHub (main or development branch)
3. Launcher downloads `manifest.json` and `BEPOZCore.psm1`
4. Interactive menu displays available scripts by category
5. Technician selects a script to execute
6. Script is downloaded from GitHub and executed
7. All output is logged to `C:\Logs\BEPOZDeployment\`
8. Temporary files are cleaned up
9. Menu returns for next selection or exit

### Branch Strategy

- **main**: Production-ready, stable scripts (use `deploy-main.bat`)
- **development**: Testing and development branch (use `deploy-dev.bat`)

This allows you to test new scripts or changes in the development branch before promoting them to production.

## BEPOZCore Module

The `BEPOZCore.psm1` module provides reusable functions for all scripts:

### Available Functions

| Function | Purpose |
|----------|---------|
| `Get-BEPOZDatabaseConfig` | Retrieves database configuration from registry |
| `New-BEPOZDatabaseConnection` | Creates SQL connection to BEPOZ database |
| `Invoke-BEPOZDatabaseQuery` | Executes parameterized SQL queries |
| `Get-BEPOZRegistryValue` | Reads Windows Registry values with error handling |
| `Write-BEPOZLog` | Writes formatted log entries to console and file |
| `Write-BEPOZAudit` | Logs audit trail entries to database |

### Usage Example

```powershell
# All scripts automatically have access to BEPOZCore functions

# Log a message
Write-BEPOZLog -Message "Starting user creation" -Level Info

# Query the database
$users = Invoke-BEPOZDatabaseQuery -Query "SELECT * FROM Users WHERE Status = @Status" -Parameters @{ Status = "Active" }

# Read registry value
$dbServer = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Database" -Name "ServerName"

# Log audit trail
Write-BEPOZAudit -Action "User Created" -Details "New user account created" -TargetUser "jdoe"
```

## Adding New Scripts

1. **Create Your Script**
   - Place it in the appropriate category folder under `scripts/`
   - Use BEPOZCore functions for logging, database access, and registry operations
   - Follow the sample script template structure

2. **Update Manifest**
   - Add an entry to `manifest.json` with all required metadata
   - Include: name, description, scriptPath, version, lastUpdated, requiresAdmin

3. **Test the Script**
   - Use `deploy-dev.bat` to test from the development branch
   - Verify logging, error handling, and functionality

4. **Promote to Production**
   - Merge development branch to main
   - Script is immediately available via `deploy-main.bat`

See `docs/developer-guide.md` for detailed instructions.

## Logging

### Log Location
`C:\Logs\BEPOZDeployment\`

### Log File Naming
`YYYYMMDD_HHmmss_ScriptName.log`

Example: `20260217_143022_CreateStandardUser.log`

### Log Entry Format
```
[2026-02-17 14:30:22] [Info] [WORKSTATION\admin] Starting user creation
[2026-02-17 14:30:25] [Success] [WORKSTATION\admin] User created successfully
```

## Configuration Requirements

### Registry Configuration
Scripts expect BEPOZ configuration in the Windows Registry:

```
HKLM:\SOFTWARE\BEPOZ\Database
  - ServerName: SQL Server instance name
  - DatabaseName: BEPOZ database name

HKLM:\SOFTWARE\BEPOZ\Network
  - DNSServer: DNS server IP
  - DomainName: Domain name
  - WorkgroupName: Workgroup name

HKLM:\SOFTWARE\BEPOZ\Users
  - DefaultHomeDrive: Default home drive
  - DefaultProfilePath: Default profile path
```

### Database Schema
The framework expects certain database tables:

- `Users`: User account information
- `AuditLog`: Audit trail logging
- `NetworkSettings`: Computer-specific network settings

## Troubleshooting

### Common Issues

**"Failed to download launcher from GitHub"**
- Verify internet connectivity
- Check GitHub PAT is valid and has `repo` scope
- Confirm repository name and owner are correct

**"Cannot continue without core module"**
- Verify `modules/BEPOZCore.psm1` exists in repository
- Check file permissions

**"Registry path not found"**
- Ensure BEPOZ is installed and configured
- Verify registry paths exist

See `docs/troubleshooting.md` for more detailed solutions.

## Security Considerations

- **GitHub PAT**: Stored only in BAT files in ScreenConnect (not in repository)
- **PAT Scope**: Use minimal scope (repo read access only)
- **PAT Rotation**: Rotate PAT periodically and update BAT files
- **Private Repository**: Prevents unauthorized access to scripts
- **Log Security**: Logs may contain sensitive info - restrict permissions
- **No Hardcoded Credentials**: Database credentials from registry only

## Maintenance

- **Scripts**: Update automatically - no deployment needed
- **Launcher**: Updates take effect immediately on next execution
- **Deploy BAT**: Requires manual update in ScreenConnect
- **Log Rotation**: Implement maintenance script to archive logs older than 90 days

## Version Information

- **Framework Version**: 1.0.0
- **PowerShell Required**: 5.1+
- **Last Updated**: 2026-02-17

## Support

For issues, questions, or contributions:
- Review `docs/troubleshooting.md`
- Check execution logs in `C:\Logs\BEPOZDeployment\`
- Contact BEPOZ IT Team

## License

Internal use only - BEPOZ IT Department
