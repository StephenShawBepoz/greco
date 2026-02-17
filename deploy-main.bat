@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM BEPOZ DEPLOYMENT FRAMEWORK BOOTSTRAP - MAIN BRANCH
REM ═══════════════════════════════════════════════════════════════════════════
REM This file deploys from the MAIN branch (production)
REM Use this for stable, production-ready deployments
REM ═══════════════════════════════════════════════════════════════════════════

setlocal EnableDelayedExpansion

REM ═══════════════════════════════════════════════════════════════════════════
REM CONFIGURATION
REM ═══════════════════════════════════════════════════════════════════════════

REM GitHub Personal Access Token (only needed for private repositories)
REM REPLACE WITH YOUR ACTUAL TOKEN - DO NOT COMMIT YOUR REAL TOKEN!
REM Leave empty for public repositories
set GITHUB_PAT=PASTE_YOUR_GITHUB_PAT_HERE

REM GitHub repository configuration
set REPO_OWNER=StephenShawBepoz
set REPO_NAME=greco
set BRANCH=main

REM ═══════════════════════════════════════════════════════════════════════════
REM BOOTSTRAP LOGIC
REM ═══════════════════════════════════════════════════════════════════════════

echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo    BEPOZ DEPLOYMENT FRAMEWORK - PRODUCTION (MAIN BRANCH)
echo    Bootstrap Initializing...
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Validate configuration
if "%GITHUB_PAT%"=="PASTE_YOUR_GITHUB_PAT_HERE" (
    echo ERROR: GitHub PAT not configured!
    echo.
    echo Please edit this BAT file and replace PASTE_YOUR_GITHUB_PAT_HERE with your
    echo actual GitHub Personal Access Token, or leave it empty for public repos.
    echo.
    echo To create a GitHub PAT:
    echo   1. Go to GitHub Settings ^> Developer settings ^> Personal access tokens
    echo   2. Generate new token with 'repo' scope
    echo   3. Copy the token and paste it in this file
    echo.
    pause
    exit /b 1
)

REM Create temporary directory
set TEMP_DIR=%TEMP%\BEPOZDeployment_Main_%RANDOM%_%TIME:~6,2%%TIME:~9,2%
mkdir "%TEMP_DIR%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to create temporary directory
    echo Location: %TEMP_DIR%
    echo.
    pause
    exit /b 1
)

echo [MAIN] Temporary directory: %TEMP_DIR%
echo [MAIN] Branch: MAIN (Production)
echo.

REM Download launcher
echo [MAIN] Downloading deployment launcher from GitHub...
echo [MAIN] Repository: %REPO_OWNER%/%REPO_NAME% (branch: %BRANCH%)
echo.

set LAUNCHER_URL=https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/contents/launcher.ps1?ref=%BRANCH%
set LAUNCHER_PATH=%TEMP_DIR%\launcher.ps1

REM Use PowerShell to download (with or without authentication based on PAT)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference = 'Stop'; $headers = @{'Accept'='application/vnd.github.v3.raw'}; if ('%GITHUB_PAT%' -ne '' -and '%GITHUB_PAT%' -ne 'PASTE_YOUR_GITHUB_PAT_HERE') { $headers['Authorization'] = 'token %GITHUB_PAT%' }; try { Write-Host '[POWERSHELL] Connecting to GitHub API (MAIN branch)...' -ForegroundColor Cyan; Invoke-WebRequest -Uri '%LAUNCHER_URL%' -Headers $headers -OutFile '%LAUNCHER_PATH%' -ErrorAction Stop; Write-Host '[POWERSHELL] Launcher downloaded successfully from MAIN.' -ForegroundColor Green; exit 0 } catch { Write-Host '[POWERSHELL] ERROR: Failed to download launcher' -ForegroundColor Red; Write-Host '[POWERSHELL] Details: ' -NoNewline -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; exit 1 }}"

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
    echo   [5] Branch name is incorrect
    echo.
    rmdir /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo.
echo [MAIN] Launcher downloaded successfully.
echo [MAIN] Launching BEPOZ Deployment Framework (Production)...
echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Execute launcher with parameters
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER_PATH%" -GitHubPAT "%GITHUB_PAT%" -RepoOwner "%REPO_OWNER%" -RepoName "%REPO_NAME%" -Branch "%BRANCH%"

set LAUNCHER_EXIT_CODE=%ERRORLEVEL%

REM Cleanup
echo.
echo [MAIN] Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul

echo [MAIN] Framework execution complete.
echo.

REM Exit with launcher's exit code
exit /b %LAUNCHER_EXIT_CODE%
