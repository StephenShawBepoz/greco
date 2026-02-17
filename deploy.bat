@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM BEPOZ DEPLOYMENT FRAMEWORK BOOTSTRAP
REM ═══════════════════════════════════════════════════════════════════════════
REM This file lives in ScreenConnect toolbox only (not in GitHub)
REM It securely stores the GitHub PAT and launches the deployment framework
REM
REM SETUP INSTRUCTIONS:
REM 1. Replace PASTE_YOUR_TOKEN_HERE with your actual GitHub Personal Access Token
REM 2. Update REPO_OWNER and REPO_NAME with your GitHub repository details
REM 3. Upload this file to your ScreenConnect toolbox
REM 4. DO NOT commit this file to version control (it contains the PAT)
REM ═══════════════════════════════════════════════════════════════════════════

setlocal EnableDelayedExpansion

REM ═══════════════════════════════════════════════════════════════════════════
REM CONFIGURATION - UPDATE THESE VALUES
REM ═══════════════════════════════════════════════════════════════════════════

REM GitHub Personal Access Token (requires 'repo' scope for private repositories)
set GITHUB_PAT=ghp_PASTE_YOUR_TOKEN_HERE

REM GitHub repository configuration
set REPO_OWNER=YourOrg
set REPO_NAME=BEPOZ-Scripts
set BRANCH=main

REM ═══════════════════════════════════════════════════════════════════════════
REM BOOTSTRAP LOGIC - DO NOT MODIFY BELOW THIS LINE
REM ═══════════════════════════════════════════════════════════════════════════

echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo    BEPOZ DEPLOYMENT FRAMEWORK
echo    Bootstrap Initializing...
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
set TEMP_DIR=%TEMP%\BEPOZDeployment_%RANDOM%_%TIME:~6,2%%TIME:~9,2%
mkdir "%TEMP_DIR%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to create temporary directory
    echo Location: %TEMP_DIR%
    echo.
    pause
    exit /b 1
)

echo [BOOTSTRAP] Temporary directory: %TEMP_DIR%
echo.

REM Download launcher
echo [BOOTSTRAP] Downloading deployment launcher from GitHub...
echo [BOOTSTRAP] Repository: %REPO_OWNER%/%REPO_NAME% (branch: %BRANCH%)
echo.

set LAUNCHER_URL=https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/contents/launcher.ps1?ref=%BRANCH%
set LAUNCHER_PATH=%TEMP_DIR%\launcher.ps1

REM Use PowerShell to download with authentication
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference = 'Stop'; $headers = @{'Authorization'='token %GITHUB_PAT%'; 'Accept'='application/vnd.github.v3.raw'}; try { Write-Host '[POWERSHELL] Connecting to GitHub API...' -ForegroundColor Cyan; Invoke-WebRequest -Uri '%LAUNCHER_URL%' -Headers $headers -OutFile '%LAUNCHER_PATH%' -ErrorAction Stop; Write-Host '[POWERSHELL] Launcher downloaded successfully.' -ForegroundColor Green; exit 0 } catch { Write-Host '[POWERSHELL] ERROR: Failed to download launcher' -ForegroundColor Red; Write-Host '[POWERSHELL] Details: ' -NoNewline -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; exit 1 }}"

if errorlevel 1 (
    echo.
    echo ═══════════════════════════════════════════════════════════════════════════
    echo FATAL ERROR: Could not download launcher from GitHub
    echo ═══════════════════════════════════════════════════════════════════════════
    echo.
    echo Possible causes:
    echo   [1] No internet connection
    echo   [2] Invalid GitHub Personal Access Token
    echo   [3] Repository not accessible (wrong name or insufficient permissions^)
    echo   [4] GitHub API is down or rate limited
    echo   [5] Branch name is incorrect
    echo.
    echo Troubleshooting:
    echo   - Verify internet connectivity
    echo   - Check GitHub PAT is valid and has 'repo' scope
    echo   - Confirm repository exists: https://github.com/%REPO_OWNER%/%REPO_NAME%
    echo   - Try accessing GitHub in a web browser
    echo.
    rmdir /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo.
echo [BOOTSTRAP] Launcher downloaded successfully.
echo [BOOTSTRAP] Launching BEPOZ Deployment Framework...
echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Execute launcher with parameters
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER_PATH%" -GitHubPAT "%GITHUB_PAT%" -RepoOwner "%REPO_OWNER%" -RepoName "%REPO_NAME%" -Branch "%BRANCH%"

set LAUNCHER_EXIT_CODE=%ERRORLEVEL%

REM Cleanup
echo.
echo [BOOTSTRAP] Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul

echo [BOOTSTRAP] Framework execution complete.
echo.

REM Exit with launcher's exit code
exit /b %LAUNCHER_EXIT_CODE%
