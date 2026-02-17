@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM BEPOZ DEPLOYMENT FRAMEWORK BOOTSTRAP - DEVELOPMENT BRANCH
REM ═══════════════════════════════════════════════════════════════════════════
REM This file deploys from the DEVELOPMENT branch (testing)
REM Use this for testing new features before promoting to production
REM ═══════════════════════════════════════════════════════════════════════════

setlocal EnableDelayedExpansion

REM ═══════════════════════════════════════════════════════════════════════════
REM CONFIGURATION
REM ═══════════════════════════════════════════════════════════════════════════

REM GitHub Personal Access Token (requires 'repo' scope for private repositories)
set GITHUB_PAT=ghp_PASTE_YOUR_TOKEN_HERE

REM GitHub repository configuration
set REPO_OWNER=YourOrg
set REPO_NAME=BEPOZ-Scripts
set BRANCH=development

REM ═══════════════════════════════════════════════════════════════════════════
REM BOOTSTRAP LOGIC
REM ═══════════════════════════════════════════════════════════════════════════

echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo    BEPOZ DEPLOYMENT FRAMEWORK - DEVELOPMENT BRANCH
echo    Bootstrap Initializing...
echo ═══════════════════════════════════════════════════════════════════════════
echo    [WARNING] This is the DEVELOPMENT branch for testing only!
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Validate configuration
if "%GITHUB_PAT%"=="ghp_PASTE_YOUR_TOKEN_HERE" (
    echo ERROR: GitHub PAT not configured!
    echo.
    echo Please edit this BAT file and replace PASTE_YOUR_TOKEN_HERE with your
    echo actual GitHub Personal Access Token.
    echo.
    pause
    exit /b 1
)

REM Create temporary directory
set TEMP_DIR=%TEMP%\BEPOZDeployment_Dev_%RANDOM%_%TIME:~6,2%%TIME:~9,2%
mkdir "%TEMP_DIR%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to create temporary directory
    echo Location: %TEMP_DIR%
    echo.
    pause
    exit /b 1
)

echo [DEV] Temporary directory: %TEMP_DIR%
echo [DEV] Branch: DEVELOPMENT (Testing)
echo.

REM Download launcher
echo [DEV] Downloading deployment launcher from GitHub...
echo [DEV] Repository: %REPO_OWNER%/%REPO_NAME% (branch: %BRANCH%)
echo.

set LAUNCHER_URL=https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/contents/launcher.ps1?ref=%BRANCH%
set LAUNCHER_PATH=%TEMP_DIR%\launcher.ps1

REM Use PowerShell to download with authentication
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference = 'Stop'; $headers = @{'Authorization'='token %GITHUB_PAT%'; 'Accept'='application/vnd.github.v3.raw'}; try { Write-Host '[POWERSHELL] Connecting to GitHub API (DEVELOPMENT branch)...' -ForegroundColor Yellow; Invoke-WebRequest -Uri '%LAUNCHER_URL%' -Headers $headers -OutFile '%LAUNCHER_PATH%' -ErrorAction Stop; Write-Host '[POWERSHELL] Launcher downloaded successfully from DEVELOPMENT.' -ForegroundColor Green; exit 0 } catch { Write-Host '[POWERSHELL] ERROR: Failed to download launcher' -ForegroundColor Red; Write-Host '[POWERSHELL] Details: ' -NoNewline -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; exit 1 }}"

if errorlevel 1 (
    echo.
    echo ═══════════════════════════════════════════════════════════════════════════
    echo FATAL ERROR: Could not download launcher from GitHub
    echo ═══════════════════════════════════════════════════════════════════════════
    echo.
    echo Possible causes:
    echo   [1] No internet connection
    echo   [2] Invalid GitHub Personal Access Token
    echo   [3] Repository not accessible
    echo   [4] GitHub API is down or rate limited
    echo   [5] Branch name is incorrect (development branch may not exist yet)
    echo.
    rmdir /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo.
echo [DEV] Launcher downloaded successfully.
echo [DEV] Launching BEPOZ Deployment Framework (Development)...
echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Execute launcher with parameters
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER_PATH%" -GitHubPAT "%GITHUB_PAT%" -RepoOwner "%REPO_OWNER%" -RepoName "%REPO_NAME%" -Branch "%BRANCH%"

set LAUNCHER_EXIT_CODE=%ERRORLEVEL%

REM Cleanup
echo.
echo [DEV] Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul

echo [DEV] Framework execution complete.
echo.

REM Exit with launcher's exit code
exit /b %LAUNCHER_EXIT_CODE%
