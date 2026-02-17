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
    [Parameter(Mandatory=$false)]
    [string]$GitHubPAT = "",

    [Parameter(Mandatory=$false)]
    [string]$RepoOwner = "StephenShawBepoz",

    [Parameter(Mandatory=$false)]
    [string]$RepoName = "greco",

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
        "Accept" = "application/vnd.github.v3.raw"
    }

    # Add authorization header only if PAT is provided (for private repos)
    if (-not [string]::IsNullOrWhiteSpace($GitHubPAT)) {
        $headers["Authorization"] = "token $GitHubPAT"
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
            Write-BepozLog -Message "User exited framework" -Level INFO
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

    # Initialize logger for this specific script
    $scriptName = $Tool.name -replace '[^a-zA-Z0-9]', ''
    $scriptLogFile = Initialize-BepozLogger -ToolName $scriptName

    Write-BepozLog -Message "=== Script Execution Started ===" -Level INFO
    Write-BepozLog -Message "Script: $($Tool.name) v$($Tool.version)" -Level INFO
    Write-BepozLog -Message "Path: $($Tool.scriptPath)" -Level INFO
    Write-BepozLog -Message "User: $env:USERNAME" -Level INFO
    Write-BepozLog -Message "Computer: $env:COMPUTERNAME" -Level INFO

    # Download script
    $scriptPath = "$global:TempDir\script_$(Get-Date -Format 'HHmmss').ps1"
    if (-not (Get-GitHubFile -FilePath $Tool.scriptPath -SavePath $scriptPath)) {
        Write-Host ""
        Write-Host "FAILED: Could not download script from GitHub" -ForegroundColor Red
        Write-BepozLog -Message "Script download failed" -Level ERROR
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
        Write-BepozLog -Message "Script execution error: $_" -Level ERROR
        Write-BepozLog -Message $_.ScriptStackTrace -Level ERROR
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
        Write-BepozLog -Message "Script completed successfully" -Level SUCCESS
    }
    else {
        Write-Host "COMPLETED WITH ERRORS" -ForegroundColor Red
        Write-BepozLog -Message "Script completed with errors" -Level ERROR
    }

    Write-BepozLog -Message "Duration: $($duration.TotalSeconds) seconds" -Level INFO
    Write-BepozLog -Message "=== Script Execution Ended ===" -Level INFO

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

    # Download modules
    Write-Host "[1/5] Downloading BepozLogger module..." -ForegroundColor Cyan
    $loggerPath = "$global:TempDir\BepozLogger.ps1"
    if (-not (Get-GitHubFile -FilePath "modules/BepozLogger.ps1" -SavePath $loggerPath)) {
        Write-Host "      FATAL: Cannot continue without logger module" -ForegroundColor Red
        exit 1
    }
    Write-Host "      BepozLogger downloaded successfully." -ForegroundColor Green

    Write-Host "[2/5] Downloading BepozDbCore module..." -ForegroundColor Cyan
    $dbCorePath = "$global:TempDir\BepozDbCore.ps1"
    if (-not (Get-GitHubFile -FilePath "modules/BepozDbCore.ps1" -SavePath $dbCorePath)) {
        Write-Host "      FATAL: Cannot continue without database module" -ForegroundColor Red
        exit 1
    }
    Write-Host "      BepozDbCore downloaded successfully." -ForegroundColor Green

    Write-Host "[3/5] Downloading BepozTheme module..." -ForegroundColor Cyan
    $themePath = "$global:TempDir\BepozTheme.ps1"
    if (-not (Get-GitHubFile -FilePath "modules/BepozTheme.ps1" -SavePath $themePath)) {
        Write-Host "      FATAL: Cannot continue without theme module" -ForegroundColor Red
        exit 1
    }
    Write-Host "      BepozTheme downloaded successfully." -ForegroundColor Green

    Write-Host "[4/5] Downloading BepozUI module..." -ForegroundColor Cyan
    $uiPath = "$global:TempDir\BepozUI.ps1"
    if (-not (Get-GitHubFile -FilePath "modules/BepozUI.ps1" -SavePath $uiPath)) {
        Write-Host "      FATAL: Cannot continue without UI module" -ForegroundColor Red
        exit 1
    }
    Write-Host "      BepozUI downloaded successfully." -ForegroundColor Green

    # Import modules in correct order (Logger first, then DbCore uses it)
    Write-Host ""
    Write-Host "Importing modules..." -ForegroundColor Cyan
    Import-Module $loggerPath -Force -ErrorAction Stop
    Write-Host "   ✓ BepozLogger imported" -ForegroundColor Green

    Import-Module $dbCorePath -Force -ErrorAction Stop
    Write-Host "   ✓ BepozDbCore imported" -ForegroundColor Green

    Import-Module $themePath -Force -ErrorAction Stop
    Write-Host "   ✓ BepozTheme imported" -ForegroundColor Green

    Import-Module $uiPath -Force -ErrorAction Stop
    Write-Host "   ✓ BepozUI imported" -ForegroundColor Green

    # Initialize logger for this session
    $logFile = Initialize-BepozLogger -ToolName "DeploymentFramework"
    if ($logFile) {
        Write-BepozLog -Message "BEPOZ Deployment Framework started" -Level INFO
        Write-BepozLog -Message "Repository: $RepoOwner/$RepoName (branch: $Branch)" -Level INFO
        Write-BepozLog -Message "User: $env:USERNAME on $env:COMPUTERNAME" -Level INFO
    }

    # Download manifest
    Write-Host ""
    Write-Host "[5/5] Downloading script manifest..." -ForegroundColor Cyan
    $manifestPath = "$global:TempDir\manifest.json"
    if (-not (Get-GitHubFile -FilePath "manifest.json" -SavePath $manifestPath)) {
        Write-Host ""
        Write-Host "FATAL: Cannot continue without manifest" -ForegroundColor Red
        Write-BepozLog -Message "Failed to download manifest" -Level ERROR
        exit 1
    }
    Write-Host "      Manifest downloaded successfully." -ForegroundColor Green

    # Parse manifest
    try {
        $global:Manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-BepozLog -Message "Manifest loaded: version $($global:Manifest.version)" -Level INFO
        Write-BepozLog -Message "Manifest contains $($global:Manifest.categories.Count) categories" -Level INFO
    }
    catch {
        Write-Host ""
        Write-Host "FATAL: Failed to parse manifest JSON" -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        Write-BepozLog -Message "Failed to parse manifest: $_" -Level ERROR
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
        Write-BepozLog -Message "Fatal error: $_" -Level ERROR
    }
    exit 1
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    Remove-Item -Path $global:TempDir -Recurse -Force -ErrorAction SilentlyContinue

    if ($global:BEPOZLogFile) {
        Write-BepozLog -Message "Framework session ended" -Level INFO
    }

    Write-Host "Thank you for using BEPOZ Deployment Framework!" -ForegroundColor Green
    Write-Host ""
}
