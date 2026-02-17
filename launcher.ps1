<#
.SYNOPSIS
    BEPOZ Deployment Framework Launcher

.DESCRIPTION
    Downloads manifest, presents interactive menu, executes selected scripts
    with comprehensive logging and error handling

.PARAMETER GitHubPAT
    GitHub Personal Access Token for private repository access

.PARAMETER RepoOwner
    GitHub repository owner (username or organization)

.PARAMETER RepoName
    GitHub repository name

.PARAMETER Branch
    Branch to download from (default: main)

.EXAMPLE
    .\launcher.ps1 -GitHubPAT "ghp_xxxxx" -RepoOwner "MyOrg" -RepoName "BEPOZ-Scripts"

.NOTES
    Version: 1.0.0
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubPAT,

    [Parameter(Mandatory=$false)]
    [string]$RepoOwner = "YourOrg",

    [Parameter(Mandatory=$false)]
    [string]$RepoName = "BEPOZ-Scripts",

    [Parameter(Mandatory=$false)]
    [string]$Branch = "main"
)

# Global variables
$global:TempDir = "$env:TEMP\BEPOZDeployment_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$global:LogDir = "C:\Logs\BEPOZDeployment"
$global:BEPOZLogFile = "$global:LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_Launcher.log"
$global:Manifest = $null

# Create necessary directories
try {
    New-Item -ItemType Directory -Path $global:TempDir -Force | Out-Null
    New-Item -ItemType Directory -Path $global:LogDir -Force | Out-Null
}
catch {
    Write-Host "ERROR: Failed to create required directories: $_" -ForegroundColor Red
    exit 1
}

# Function to download file from GitHub
function Get-GitHubFile {
    <#
    .SYNOPSIS
        Downloads a file from GitHub private repository
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$SavePath
    )

    $url = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$FilePath`?ref=$Branch"
    $headers = @{
        "Authorization" = "token $GitHubPAT"
        "Accept" = "application/vnd.github.v3.raw"
    }

    try {
        Invoke-WebRequest -Uri $url -Headers $headers -OutFile $SavePath -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to download $FilePath from GitHub" -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        Write-Host "URL: $url" -ForegroundColor Yellow
        return $false
    }
}

# Function to display header
function Show-Header {
    param([string]$Title)

    Clear-Host
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   BEPOZ DEPLOYMENT FRAMEWORK" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# Function to display main menu
function Show-MainMenu {
    while ($true) {
        Show-Header "Main Menu"

        Write-Host "Available Categories:" -ForegroundColor Yellow
        Write-Host ""

        for ($i = 0; $i -lt $global:Manifest.categories.Count; $i++) {
            $category = $global:Manifest.categories[$i]
            Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor Green
            Write-Host "$($category.name)" -NoNewline -ForegroundColor White
            Write-Host " - $($category.description)" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "  [0] Exit Framework" -ForegroundColor Red
        Write-Host ""

        $selection = Read-Host "Select category (0-$($global:Manifest.categories.Count))"

        if ($selection -eq "0") {
            Write-BEPOZLog -Message "User exited framework" -Level Info
            return
        }

        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $global:Manifest.categories.Count) {
            $category = $global:Manifest.categories[$index]

            # Check if category has subcategories or direct tools
            if ($category.PSObject.Properties.Name -contains "subcategories") {
                Show-SubcategoryMenu -Category $category
            }
            elseif ($category.PSObject.Properties.Name -contains "tools") {
                Show-ToolMenu -CategoryName $category.name -Tools $category.tools
            }
        }
        else {
            Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Function to display subcategory menu
function Show-SubcategoryMenu {
    param($Category)

    while ($true) {
        Show-Header "$($Category.name) - Select Subcategory"

        Write-Host "Available Subcategories:" -ForegroundColor Yellow
        Write-Host ""

        for ($i = 0; $i -lt $Category.subcategories.Count; $i++) {
            $subcategory = $Category.subcategories[$i]
            Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor Green
            Write-Host "$($subcategory.name)" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "  [0] Back to Main Menu" -ForegroundColor Yellow
        Write-Host ""

        $selection = Read-Host "Select subcategory (0-$($Category.subcategories.Count))"

        if ($selection -eq "0") {
            return
        }

        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $Category.subcategories.Count) {
            $subcategory = $Category.subcategories[$index]
            Show-ToolMenu -CategoryName "$($Category.name) > $($subcategory.name)" -Tools $subcategory.tools
        }
        else {
            Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Function to display tool selection menu
function Show-ToolMenu {
    param(
        [string]$CategoryName,
        [array]$Tools
    )

    while ($true) {
        Show-Header "$CategoryName - Select Tool"

        Write-Host "Available Tools:" -ForegroundColor Yellow
        Write-Host ""

        for ($i = 0; $i -lt $Tools.Count; $i++) {
            $tool = $Tools[$i]
            Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor Green
            Write-Host "$($tool.name)" -NoNewline -ForegroundColor White
            Write-Host " (v$($tool.version))" -ForegroundColor Cyan

            Write-Host "      $($tool.description)" -ForegroundColor Gray

            if ($tool.requiresAdmin) {
                Write-Host "      [Requires Admin]" -ForegroundColor Red
            }

            if ($tool.documentationUrl) {
                Write-Host "      Docs: $($tool.documentationUrl)" -ForegroundColor DarkGray
            }

            Write-Host ""
        }

        Write-Host "  [0] Back" -ForegroundColor Yellow
        Write-Host ""

        $selection = Read-Host "Select tool to execute (0-$($Tools.Count))"

        if ($selection -eq "0") {
            return
        }

        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $Tools.Count) {
            $tool = $Tools[$index]
            Execute-Script -Tool $tool
        }
        else {
            Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Function to execute selected script
function Execute-Script {
    param($Tool)

    Show-Header "Executing: $($Tool.name)"

    Write-Host "Tool: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($Tool.name) v$($Tool.version)" -ForegroundColor White
    Write-Host "Description: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($Tool.description)" -ForegroundColor White
    Write-Host ""

    # Check admin requirements
    if ($Tool.requiresAdmin) {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Host "WARNING: This script requires administrator privileges!" -ForegroundColor Red
            Write-Host "Current session is not elevated. Script may fail." -ForegroundColor Yellow
            Write-Host ""
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                Write-Host "Execution cancelled." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return
            }
        }
    }

    Write-Host "Downloading script from GitHub..." -ForegroundColor Cyan

    # Create script-specific log file
    $scriptLogFile = "$global:LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Tool.name -replace '[^a-zA-Z0-9]', '').log"
    $global:BEPOZLogFile = $scriptLogFile

    Write-BEPOZLog -Message "=== Script Execution Started ===" -Level Info
    Write-BEPOZLog -Message "Script: $($Tool.name) v$($Tool.version)" -Level Info
    Write-BEPOZLog -Message "Path: $($Tool.scriptPath)" -Level Info
    Write-BEPOZLog -Message "User: $env:USERNAME" -Level Info
    Write-BEPOZLog -Message "Computer: $env:COMPUTERNAME" -Level Info

    # Download script
    $scriptPath = "$global:TempDir\script_$(Get-Date -Format 'HHmmss').ps1"
    if (-not (Get-GitHubFile -FilePath $Tool.scriptPath -SavePath $scriptPath)) {
        Write-Host ""
        Write-Host "FAILED: Could not download script from GitHub" -ForegroundColor Red
        Write-BEPOZLog -Message "Script download failed" -Level Error
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-Host "Script downloaded successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "SCRIPT OUTPUT:" -ForegroundColor Cyan
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    # Execute script
    $startTime = Get-Date
    try {
        & $scriptPath
        $exitCode = $LASTEXITCODE
        $success = ($null -eq $exitCode) -or ($exitCode -eq 0)
    }
    catch {
        $success = $false
        Write-BEPOZLog -Message "Script execution error: $_" -Level Error
        Write-BEPOZLog -Message $_.ScriptStackTrace -Level Error
        Write-Host ""
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Log completion
    Write-Host ""
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    if ($success) {
        Write-Host "COMPLETED SUCCESSFULLY" -ForegroundColor Green
        Write-BEPOZLog -Message "Script completed successfully" -Level Success
    }
    else {
        Write-Host "COMPLETED WITH ERRORS" -ForegroundColor Red
        Write-BEPOZLog -Message "Script completed with errors" -Level Error
    }

    Write-BEPOZLog -Message "Duration: $($duration.TotalSeconds) seconds" -Level Info
    Write-BEPOZLog -Message "=== Script Execution Ended ===" -Level Info

    Write-Host "Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
    Write-Host "Log file: $scriptLogFile" -ForegroundColor Gray
    Write-Host ""

    # Cleanup script file
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue

    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ═══════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════

try {
    # Initialize log
    Add-Content -Path $global:BEPOZLogFile -Value "BEPOZ Deployment Framework - Session Started"

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   BEPOZ DEPLOYMENT FRAMEWORK" -ForegroundColor Cyan
    Write-Host "   Initializing..." -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Download core module
    Write-Host "[1/3] Downloading core utilities module..." -ForegroundColor Cyan
    $coreModulePath = "$global:TempDir\BEPOZCore.psm1"
    if (-not (Get-GitHubFile -FilePath "modules/BEPOZCore.psm1" -SavePath $coreModulePath)) {
        Write-Host ""
        Write-Host "FATAL: Cannot continue without core module" -ForegroundColor Red
        exit 1
    }
    Write-Host "      Core module downloaded successfully." -ForegroundColor Green

    # Import core module
    Write-Host "[2/3] Importing core module..." -ForegroundColor Cyan
    Import-Module $coreModulePath -Force -ErrorAction Stop
    Write-Host "      Core module imported successfully." -ForegroundColor Green

    # Now we can use Write-BEPOZLog
    Write-BEPOZLog -Message "BEPOZ Deployment Framework started" -Level Info
    Write-BEPOZLog -Message "Repository: $RepoOwner/$RepoName (branch: $Branch)" -Level Info
    Write-BEPOZLog -Message "User: $env:USERNAME on $env:COMPUTERNAME" -Level Info

    # Download manifest
    Write-Host "[3/3] Downloading script manifest..." -ForegroundColor Cyan
    $manifestPath = "$global:TempDir\manifest.json"
    if (-not (Get-GitHubFile -FilePath "manifest.json" -SavePath $manifestPath)) {
        Write-Host ""
        Write-Host "FATAL: Cannot continue without manifest" -ForegroundColor Red
        Write-BEPOZLog -Message "Failed to download manifest" -Level Error
        exit 1
    }
    Write-Host "      Manifest downloaded successfully." -ForegroundColor Green

    # Parse manifest
    try {
        $global:Manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-BEPOZLog -Message "Manifest loaded: version $($global:Manifest.version)" -Level Info
        Write-BEPOZLog -Message "Manifest contains $($global:Manifest.categories.Count) categories" -Level Info
    }
    catch {
        Write-Host ""
        Write-Host "FATAL: Failed to parse manifest JSON" -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        Write-BEPOZLog -Message "Failed to parse manifest: $_" -Level Error
        exit 1
    }

    Write-Host ""
    Write-Host "Initialization complete! Launching main menu..." -ForegroundColor Green
    Start-Sleep -Seconds 2

    # Show main menu
    Show-MainMenu
}
catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    if ($global:BEPOZLogFile) {
        Write-BEPOZLog -Message "Fatal error: $_" -Level Error
    }
    exit 1
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    Remove-Item -Path $global:TempDir -Recurse -Force -ErrorAction SilentlyContinue

    if ($global:BEPOZLogFile) {
        Write-BEPOZLog -Message "Framework session ended" -Level Info
    }

    Write-Host "Thank you for using BEPOZ Deployment Framework!" -ForegroundColor Green
    Write-Host ""
}
