# BEPOZ Deployment Framework - Troubleshooting Guide

This guide helps resolve common issues with the BEPOZ Deployment Framework.

## Table of Contents

1. [Bootstrap Issues](#bootstrap-issues)
2. [Launcher Issues](#launcher-issues)
3. [Script Execution Issues](#script-execution-issues)
4. [Database Issues](#database-issues)
5. [Registry Issues](#registry-issues)
6. [Logging Issues](#logging-issues)
7. [Network Issues](#network-issues)

---

## Bootstrap Issues

### ERROR: GitHub PAT not configured

**Symptom:**
```
ERROR: GitHub PAT not configured!
Please edit this BAT file and replace PASTE_YOUR_TOKEN_HERE...
```

**Solution:**
1. Edit the `deploy-main.bat` or `deploy-dev.bat` file
2. Replace `ghp_PASTE_YOUR_TOKEN_HERE` with your actual GitHub Personal Access Token
3. Save the file
4. Re-upload to ScreenConnect if necessary

**How to Generate a GitHub PAT:**
1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token"
3. Give it a descriptive name (e.g., "BEPOZ Deployment")
4. Select scope: `repo` (Full control of private repositories)
5. Click "Generate token"
6. Copy the token immediately (you won't see it again!)

---

### FATAL ERROR: Could not download launcher from GitHub

**Symptom:**
```
FATAL ERROR: Could not download launcher from GitHub

Possible causes:
  [1] No internet connection
  [2] Invalid GitHub Personal Access Token
  ...
```

**Diagnosis:**

1. **Check Internet Connection**
   ```powershell
   Test-NetConnection -ComputerName github.com -Port 443
   ```
   - If this fails, check firewall and proxy settings

2. **Verify GitHub PAT**
   ```powershell
   $pat = "ghp_YOUR_TOKEN_HERE"
   $headers = @{"Authorization" = "token $pat"}
   Invoke-WebRequest -Uri "https://api.github.com/user" -Headers $headers
   ```
   - Should return your GitHub user info
   - If 401 error: Token is invalid
   - If 403 error: Token lacks required scope

3. **Verify Repository Access**
   - Open browser and go to: `https://github.com/YourOrg/BEPOZ-Scripts`
   - Ensure you can see the repository
   - Check repository is private (PAT required) or public

4. **Check Branch Name**
   - Verify `development` branch exists (for `deploy-dev.bat`)
   - Verify `main` branch exists (for `deploy-main.bat`)

**Solutions:**
- Regenerate GitHub PAT with correct scopes
- Check repository name spelling in BAT file
- Ensure repository is accessible
- Create missing branches in GitHub

---

### ERROR: Failed to create temporary directory

**Symptom:**
```
ERROR: Failed to create temporary directory
Location: C:\Users\...\AppData\Local\Temp\BEPOZDeployment_...
```

**Causes:**
- Insufficient disk space
- Permissions issue on TEMP directory
- TEMP directory doesn't exist

**Solutions:**
1. Check disk space: `Get-PSDrive C`
2. Verify TEMP directory exists: `echo %TEMP%`
3. Check permissions on TEMP directory
4. Clean up old temp files:
   ```powershell
   Remove-Item $env:TEMP\BEPOZDeployment_* -Recurse -Force
   ```

---

## Launcher Issues

### FATAL: Cannot continue without core module

**Symptom:**
```
[1/3] Downloading core utilities module...
ERROR: Failed to download modules/BEPOZCore.psm1 from GitHub
FATAL: Cannot continue without core module
```

**Causes:**
- `modules/BEPOZCore.psm1` doesn't exist in repository
- GitHub API rate limiting
- Repository access issue

**Solutions:**
1. Verify file exists in repository:
   - Browse to `https://github.com/YourOrg/BEPOZ-Scripts/blob/main/modules/BEPOZCore.psm1`
2. Check GitHub API rate limits:
   ```powershell
   $pat = "ghp_YOUR_TOKEN"
   $headers = @{"Authorization" = "token $pat"}
   Invoke-WebRequest -Uri "https://api.github.com/rate_limit" -Headers $headers | ConvertFrom-Json
   ```
3. Wait 1 hour if rate limited
4. Ensure file is committed and pushed to GitHub

---

### FATAL: Failed to parse manifest JSON

**Symptom:**
```
[3/3] Downloading script manifest...
FATAL: Failed to parse manifest JSON
Details: Invalid JSON syntax...
```

**Causes:**
- Syntax error in `manifest.json`
- Corrupted file download

**Solutions:**
1. Validate JSON syntax: Use [jsonlint.com](https://jsonlint.com)
2. Check for common errors:
   - Missing commas between items
   - Trailing commas before closing brackets
   - Unescaped quotes in strings
   - Missing quotes around keys
3. Re-download file manually and inspect
4. Check file encoding (should be UTF-8)

---

### Menu displays no categories/tools

**Symptom:**
- Menu loads but shows no scripts
- "Available Categories:" followed by nothing

**Causes:**
- Empty manifest
- Manifest structure issue
- Wrong branch selected

**Solutions:**
1. Check manifest has categories:
   ```powershell
   Get-Content manifest.json | ConvertFrom-Json | Select-Object -ExpandProperty categories
   ```
2. Verify branch matches BAT file configuration
3. Check manifest structure matches documented format

---

## Script Execution Issues

### Script execution error: File not found

**Symptom:**
```
ERROR: Failed to download script from GitHub
Details: 404 Not Found
```

**Causes:**
- Script file doesn't exist at specified path
- scriptPath in manifest is incorrect
- File not committed to GitHub

**Solutions:**
1. Verify file exists in repository at exact path from manifest
2. Check for typos in `scriptPath` in manifest.json
3. Ensure file is committed and pushed:
   ```bash
   git status
   git push origin main
   ```
4. Verify branch name in BAT file matches where file exists

---

### This script requires administrator privileges

**Symptom:**
```
WARNING: This script requires administrator privileges!
Current session is not elevated. Script may fail.
```

**Causes:**
- Script has `requiresAdmin: true` in manifest
- PowerShell not running as administrator
- User not in Administrators group

**Solutions:**
1. Right-click PowerShell → "Run as Administrator"
2. Or right-click `deploy.bat` → "Run as Administrator"
3. Or add user to Administrators group (if appropriate)
4. Update manifest if script doesn't actually need admin rights

---

### Script execution timeout

**Symptom:**
- Script runs indefinitely
- No response from script

**Causes:**
- Script waiting for user input that isn't visible
- Infinite loop in script
- External process hanging

**Solutions:**
1. Press Ctrl+C to cancel
2. Review script for blocking operations:
   - `Read-Host` prompts
   - Waiting for external processes
   - Infinite loops
3. Add timeout parameters to long-running operations
4. Test script locally before adding to framework

---

## Database Issues

### Failed to read database config

**Symptom:**
```
ERROR: Failed to read database config
Details: Registry path not found: HKLM:\SOFTWARE\BEPOZ\Database
```

**Causes:**
- BEPOZ not installed
- Registry keys missing
- Incorrect registry path

**Solutions:**
1. Verify BEPOZ installation
2. Manually check registry:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\BEPOZ\Database"
   ```
3. Create missing registry keys if needed:
   ```powershell
   New-Item -Path "HKLM:\SOFTWARE\BEPOZ" -Name "Database" -Force
   Set-ItemProperty -Path "HKLM:\SOFTWARE\BEPOZ\Database" -Name "ServerName" -Value "SQLSERVER01"
   Set-ItemProperty -Path "HKLM:\SOFTWARE\BEPOZ\Database" -Name "DatabaseName" -Value "BEPOZ"
   ```

---

### Failed to connect to database

**Symptom:**
```
ERROR: Failed to connect to database
Details: A network-related or instance-specific error occurred...
```

**Causes:**
- SQL Server not running
- Network connectivity issue
- Firewall blocking port 1433
- Incorrect server name

**Solutions:**
1. Test SQL Server connectivity:
   ```powershell
   Test-NetConnection -ComputerName SQLSERVER01 -Port 1433
   ```
2. Verify SQL Server service is running:
   ```powershell
   Get-Service -Name MSSQLSERVER
   ```
3. Check Windows Firewall allows SQL Server
4. Test connection with SQL Server Management Studio
5. Verify Integrated Security is enabled (or provide credentials)

---

### Database query failed

**Symptom:**
```
ERROR: Database query failed
Details: Invalid object name 'Users'
```

**Causes:**
- Table doesn't exist
- Wrong database selected
- Insufficient permissions

**Solutions:**
1. Verify table exists:
   ```sql
   SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users'
   ```
2. Check database name in registry
3. Verify user has SELECT/INSERT/UPDATE permissions
4. Review database schema requirements in README.md

---

## Registry Issues

### Registry path not found

**Symptom:**
```
ERROR: Failed to read registry value HKLM:\SOFTWARE\BEPOZ\...\...
Details: Registry path not found
```

**Causes:**
- Registry key doesn't exist
- BEPOZ not fully configured
- Incorrect path in script

**Solutions:**
1. Create missing registry keys (see Database Issues above)
2. Check for typos in registry path
3. Use Registry Editor (regedit) to manually verify path
4. Ensure script has permission to read registry (usually not an issue for HKLM:\SOFTWARE)

---

### Access denied reading registry

**Symptom:**
```
ERROR: Access denied when reading registry
```

**Causes:**
- Insufficient permissions
- Registry key has restricted ACL

**Solutions:**
1. Run as Administrator
2. Check registry key permissions in regedit
3. Add user to appropriate group with registry access
4. Modify registry key ACL if necessary

---

## Logging Issues

### Logs not being written

**Symptom:**
- Script executes but log file is empty or not created
- No files in `C:\Logs\BEPOZDeployment\`

**Causes:**
- Insufficient permissions
- Directory doesn't exist
- Disk full

**Solutions:**
1. Check directory exists:
   ```powershell
   Test-Path "C:\Logs\BEPOZDeployment"
   ```
2. Create directory manually:
   ```powershell
   New-Item -Path "C:\Logs\BEPOZDeployment" -ItemType Directory -Force
   ```
3. Check disk space: `Get-PSDrive C`
4. Verify user has write permissions on C:\Logs

---

### Log files too large

**Symptom:**
- Log files consuming too much disk space
- C:\Logs directory very large

**Solutions:**
1. Implement log rotation:
   ```powershell
   # Delete logs older than 90 days
   Get-ChildItem "C:\Logs\BEPOZDeployment" -Filter "*.log" |
     Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } |
     Remove-Item -Force
   ```
2. Archive old logs:
   ```powershell
   # Compress logs older than 30 days
   $oldLogs = Get-ChildItem "C:\Logs\BEPOZDeployment" -Filter "*.log" |
     Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

   Compress-Archive -Path $oldLogs -DestinationPath "C:\Logs\Archive_$(Get-Date -Format 'yyyyMMdd').zip"
   $oldLogs | Remove-Item -Force
   ```
3. Schedule cleanup task in Windows Task Scheduler

---

## Network Issues

### DNS configuration failed

**Symptom:**
```
ERROR: Failed to configure DNS for Ethernet
```

**Causes:**
- Network adapter not found
- Insufficient permissions
- Adapter disabled

**Solutions:**
1. List network adapters:
   ```powershell
   Get-NetAdapter
   ```
2. Enable disabled adapter:
   ```powershell
   Enable-NetAdapter -Name "Ethernet"
   ```
3. Run as Administrator
4. Check adapter name matches script expectations

---

### Cannot retrieve network settings from database

**Symptom:**
```
Warning: Could not query network settings from database
```

**Causes:**
- NetworkSettings table doesn't exist
- Database connection failed
- Query syntax error

**Solutions:**
1. Create NetworkSettings table if needed:
   ```sql
   CREATE TABLE NetworkSettings (
     ComputerName NVARCHAR(50),
     SettingName NVARCHAR(50),
     SettingValue NVARCHAR(255)
   )
   ```
2. This is usually a non-fatal warning - script continues with defaults
3. Review database schema requirements

---

## General Troubleshooting Steps

### Enable Verbose Logging

For detailed troubleshooting, enable PowerShell verbose logging:

```powershell
$VerbosePreference = "Continue"
& .\launcher.ps1 -GitHubPAT "your_pat" -Verbose
```

---

### Check Execution Policy

If scripts won't run:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy (if needed)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

### Review Log Files

Always check log files for detailed error information:

```powershell
# View most recent log
Get-ChildItem "C:\Logs\BEPOZDeployment" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Search logs for errors
Get-ChildItem "C:\Logs\BEPOZDeployment" -Filter "*.log" |
  Select-String -Pattern "ERROR" -Context 2, 2
```

---

### Test Individual Components

Test components separately:

**Test BEPOZCore Module:**
```powershell
Import-Module .\modules\BEPOZCore.psm1
Get-BEPOZDatabaseConfig
```

**Test Manifest:**
```powershell
Get-Content .\manifest.json | ConvertFrom-Json
```

**Test Script:**
```powershell
$global:BEPOZLogFile = "C:\Logs\test.log"
Import-Module .\modules\BEPOZCore.psm1
& .\scripts\user-management\CreateStandardUser.ps1
```

---

## Getting Help

If you're still experiencing issues:

1. **Check Logs**: Review detailed execution logs in `C:\Logs\BEPOZDeployment\`
2. **Review Documentation**: README.md and developer-guide.md
3. **Test Components**: Test each component independently
4. **Contact Support**: BEPOZ IT Team with:
   - Error messages
   - Log files
   - Steps to reproduce
   - Environment details (OS version, PowerShell version)

---

## Common Solutions Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| "GitHub PAT not configured" | Edit BAT file, replace placeholder with real PAT |
| "Cannot download launcher" | Check internet, verify PAT, confirm repo name |
| "Registry path not found" | Create registry keys, verify BEPOZ installed |
| "Database connection failed" | Test SQL Server connectivity, check firewall |
| "Access denied" | Run as Administrator |
| "Script not found" | Check scriptPath in manifest, verify file committed |
| "Logs not being written" | Create C:\Logs\BEPOZDeployment directory |
| "Invalid JSON" | Validate manifest.json syntax |

---

**Last Updated**: 2026-02-17
**Framework Version**: 1.0.0
