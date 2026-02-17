<#
.SYNOPSIS
    BepozLogger - Centralized logging for Bepoz Toolkit tools
.DESCRIPTION
    Provides standardized logging functions for all toolkit tools
    - Writes to C:\Bepoz\Toolkit\Logs\
    - Logs user actions, queries, performance, errors
    - Automatic log rotation (keeps 30 days)
    - Fallback to TEMP if C:\ not writable
.NOTES
    Version: 1.0.0
    Author: Bepoz Support Team
    Last Updated: 2026-02-11
#>

#region Configuration
$Script:LogDirectory = "C:\Bepoz\Toolkit\Logs"
$Script:LogRetentionDays = 30
$Script:CurrentLogFile = $null
$Script:LoggingEnabled = $true
$Script:FallbackToTemp = $true
#endregion

#region Initialization
function Initialize-BepozLogger {
    <#
    .SYNOPSIS
        Initializes the logging system and creates log directory
    .PARAMETER ToolName
        Name of the tool (used in log filename)
    .OUTPUTS
        String - Path to the current log file, or $null if initialization failed
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName
    )

    try {
        # Create log directory if it doesn't exist
        if (-not (Test-Path $Script:LogDirectory)) {
            try {
                New-Item -Path $Script:LogDirectory -ItemType Directory -Force | Out-Null
                Write-Host "[Logger] Created log directory: $Script:LogDirectory" -ForegroundColor Green
            }
            catch {
                # Fallback to TEMP if C:\ not writable
                if ($Script:FallbackToTemp) {
                    $Script:LogDirectory = Join-Path $env:TEMP "BepozToolkit\Logs"
                    New-Item -Path $Script:LogDirectory -ItemType Directory -Force | Out-Null
                    Write-Host "[Logger] Using fallback log directory: $Script:LogDirectory" -ForegroundColor Yellow
                }
                else {
                    Write-Host "[Logger] Failed to create log directory: $($_.Exception.Message)" -ForegroundColor Red
                    $Script:LoggingEnabled = $false
                    return $null
                }
            }
        }

        # Create log filename: ToolName_YYYYMMDD.log
        $date = Get-Date -Format "yyyyMMdd"
        $logFileName = "$($ToolName -replace '[^a-zA-Z0-9]', '')_$date.log"
        $Script:CurrentLogFile = Join-Path $Script:LogDirectory $logFileName

        # Write initialization entry
        $initMsg = "=== LOG STARTED ==="
        $initDetails = @"
Tool: $ToolName
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
Computer: $env:COMPUTERNAME
PowerShell: $($PSVersionTable.PSVersion.ToString())
Log File: $Script:CurrentLogFile
"@

        Add-Content -Path $Script:CurrentLogFile -Value "$initMsg`r`n$initDetails`r`n" -ErrorAction Stop

        # Clean up old logs
        Remove-OldLogs

        Write-Host "[Logger] Initialized: $Script:CurrentLogFile" -ForegroundColor Green
        return $Script:CurrentLogFile

    }
    catch {
        Write-Host "[Logger] Initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $Script:LoggingEnabled = $false
        return $null
    }
}

function Remove-OldLogs {
    <#
    .SYNOPSIS
        Removes log files older than retention period
    #>

    try {
        $cutoffDate = (Get-Date).AddDays(-$Script:LogRetentionDays)
        $oldLogs = Get-ChildItem -Path $Script:LogDirectory -Filter "*.log" -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($log in $oldLogs) {
            Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            Write-Verbose "Deleted old log: $($log.Name)"
        }

        if ($oldLogs.Count -gt 0) {
            Write-Host "[Logger] Cleaned up $($oldLogs.Count) old log file(s)" -ForegroundColor Gray
        }
    }
    catch {
        # Silent fail on cleanup
    }
}
#endregion

#region Core Logging Functions
function Write-BepozLog {
    <#
    .SYNOPSIS
        Writes a log entry to the current log file
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, WARN, ERROR, SUCCESS, ACTION, QUERY, PERF)
    .PARAMETER Details
        Optional additional details (shown on separate lines)
    .EXAMPLE
        Write-BepozLog -Message "User clicked Run button" -Level ACTION
    .EXAMPLE
        Write-BepozLog -Message "Database query failed" -Level ERROR -Details $_.Exception.Message
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'ACTION', 'QUERY', 'PERF')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$Details = ""
    )

    if (-not $Script:LoggingEnabled -or -not $Script:CurrentLogFile) {
        return
    }

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

        $logEntry = "[$timestamp] [$user] [$Level] $Message"

        if ($Details) {
            $logEntry += "`r`n  Details: $Details"
        }

        Add-Content -Path $Script:CurrentLogFile -Value $logEntry -ErrorAction Stop

    }
    catch {
        # Silent fail on logging errors to avoid breaking tools
    }
}

function Write-BepozLogAction {
    <#
    .SYNOPSIS
        Logs a user action
    .PARAMETER Action
        Description of the action (e.g., "Clicked Run button", "Selected Venue: Main")
    .EXAMPLE
        Write-BepozLogAction "User opened tool"
        Write-BepozLogAction "Selected workstation: ID=5, Name=POS-01"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action
    )

    Write-BepozLog -Message $Action -Level ACTION
}

function Write-BepozLogQuery {
    <#
    .SYNOPSIS
        Logs a database query with performance metrics
    .PARAMETER Query
        SQL query text
    .PARAMETER Parameters
        Query parameters (hashtable)
    .PARAMETER DurationMs
        Query execution time in milliseconds
    .PARAMETER RowCount
        Number of rows affected/returned
    .EXAMPLE
        Write-BepozLogQuery -Query "SELECT * FROM Venue" -DurationMs 45 -RowCount 12
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$DurationMs = 0,

        [Parameter(Mandatory = $false)]
        [int]$RowCount = 0
    )

    # Sanitize query for logging (remove extra whitespace)
    $cleanQuery = $Query -replace '\s+', ' ' -replace '^\s+|\s+$', ''

    $message = "SQL: $cleanQuery"

    $details = "Duration: ${DurationMs}ms | Rows: $RowCount"
    if ($Parameters.Count -gt 0) {
        $paramStr = ($Parameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
        $details += " | Params: $paramStr"
    }

    Write-BepozLog -Message $message -Level QUERY -Details $details
}

function Write-BepozLogPerformance {
    <#
    .SYNOPSIS
        Logs performance metrics for an operation
    .PARAMETER Operation
        Name of the operation
    .PARAMETER DurationMs
        Duration in milliseconds
    .PARAMETER ItemCount
        Optional number of items processed
    .EXAMPLE
        Write-BepozLogPerformance -Operation "Bulk insert" -DurationMs 2345 -ItemCount 150
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [int]$DurationMs,

        [Parameter(Mandatory = $false)]
        [int]$ItemCount = 0
    )

    $message = "PERF: $Operation completed in ${DurationMs}ms"
    $details = ""

    if ($ItemCount -gt 0) {
        $avgMs = [math]::Round($DurationMs / $ItemCount, 2)
        $details = "Items: $ItemCount | Avg: ${avgMs}ms/item"
    }

    Write-BepozLog -Message $message -Level PERF -Details $details
}

function Write-BepozLogError {
    <#
    .SYNOPSIS
        Logs an error with full details
    .PARAMETER Message
        Error message
    .PARAMETER Exception
        Optional exception object
    .PARAMETER StackTrace
        Optional stack trace
    .EXAMPLE
        Write-BepozLogError -Message "Failed to connect" -Exception $_.Exception
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception = $null,

        [Parameter(Mandatory = $false)]
        [string]$StackTrace = ""
    )

    $details = ""

    if ($Exception) {
        $details = "Exception: $($Exception.GetType().Name)`r`n  Message: $($Exception.Message)"
        if ($Exception.InnerException) {
            $details += "`r`n  Inner: $($Exception.InnerException.Message)"
        }
    }

    if ($StackTrace) {
        $details += "`r`n  Stack: $StackTrace"
    }

    Write-BepozLog -Message $Message -Level ERROR -Details $details
}
#endregion

#region Helper Functions
function Measure-BepozOperation {
    <#
    .SYNOPSIS
        Measures execution time of a script block and logs performance
    .PARAMETER Name
        Name of the operation
    .PARAMETER ScriptBlock
        Code to execute and measure
    .OUTPUTS
        Returns the result of the script block
    .EXAMPLE
        $result = Measure-BepozOperation -Name "Load Venues" -ScriptBlock {
            Invoke-BepozQuery -Query "SELECT * FROM Venue"
        }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $result = & $ScriptBlock
        $stopwatch.Stop()

        Write-BepozLogPerformance -Operation $Name -DurationMs $stopwatch.ElapsedMilliseconds

        return $result
    }
    catch {
        $stopwatch.Stop()
        Write-BepozLogError -Message "Operation failed: $Name" -Exception $_.Exception
        throw
    }
}

function Get-BepozLogPath {
    <#
    .SYNOPSIS
        Gets the current log file path
    .OUTPUTS
        String - Path to current log file
    #>

    return $Script:CurrentLogFile
}
#endregion

#region Module Exports
Export-ModuleMember -Function @(
    'Initialize-BepozLogger',
    'Write-BepozLog',
    'Write-BepozLogAction',
    'Write-BepozLogQuery',
    'Write-BepozLogPerformance',
    'Write-BepozLogError',
    'Measure-BepozOperation',
    'Get-BepozLogPath'
)

# Display load message if run interactively
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "[BepozLogger v1.0.0] Module loaded successfully" -ForegroundColor Green
}
#endregion
