<#
.SYNOPSIS
    Core utilities for BEPOZ onboarding scripts

.DESCRIPTION
    Provides centralized functions for database access, registry operations,
    logging, and auditing

.NOTES
    Version: 1.0.0
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
#>

# Get BEPOZ database connection information from registry
function Get-BEPOZDatabaseConfig {
    <#
    .SYNOPSIS
        Retrieves database server and database name from registry

    .DESCRIPTION
        Reads BEPOZ database configuration from Windows Registry
        Location: HKLM:\SOFTWARE\BEPOZ\Database

    .EXAMPLE
        $config = Get-BEPOZDatabaseConfig
        Write-Host "Server: $($config.ServerName)"
    #>
    [CmdletBinding()]
    param()

    try {
        $regPath = "HKLM:\SOFTWARE\BEPOZ\Database"

        # Check if registry path exists
        if (-not (Test-Path $regPath)) {
            throw "Registry path not found: $regPath. Ensure BEPOZ is properly installed."
        }

        $config = @{
            ServerName = (Get-ItemProperty -Path $regPath -Name "ServerName" -ErrorAction Stop).ServerName
            DatabaseName = (Get-ItemProperty -Path $regPath -Name "DatabaseName" -ErrorAction Stop).DatabaseName
        }

        if ([string]::IsNullOrWhiteSpace($config.ServerName) -or [string]::IsNullOrWhiteSpace($config.DatabaseName)) {
            throw "Database configuration is incomplete in registry"
        }

        return $config
    }
    catch {
        Write-BEPOZLog -Message "Failed to read database config: $_" -Level Error
        throw
    }
}

# Create database connection
function New-BEPOZDatabaseConnection {
    <#
    .SYNOPSIS
        Creates and opens SQL connection to BEPOZ database

    .DESCRIPTION
        Creates a new SQL Server connection using configuration from registry.
        Uses Windows Integrated Security.

    .EXAMPLE
        $conn = New-BEPOZDatabaseConnection
        # Use connection...
        $conn.Close()
    #>
    [CmdletBinding()]
    param()

    $config = Get-BEPOZDatabaseConfig
    $connectionString = "Server=$($config.ServerName);Database=$($config.DatabaseName);Integrated Security=True;Connection Timeout=30;"

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        Write-BEPOZLog -Message "Database connection established to $($config.ServerName)\$($config.DatabaseName)" -Level Info
        return $connection
    }
    catch {
        Write-BEPOZLog -Message "Failed to connect to database: $_" -Level Error
        throw
    }
}

# Execute database query
function Invoke-BEPOZDatabaseQuery {
    <#
    .SYNOPSIS
        Executes parameterized SQL query and returns results

    .DESCRIPTION
        Executes a SQL query with optional parameters. Returns DataTable with results.
        Automatically handles connection lifecycle.

    .PARAMETER Query
        SQL query to execute. Use @ParameterName for parameterized values.

    .PARAMETER Parameters
        Hashtable of parameters. Keys should match parameter names in query (without @).

    .EXAMPLE
        $results = Invoke-BEPOZDatabaseQuery -Query "SELECT * FROM Users WHERE Status = @Status" -Parameters @{ Status = "Active" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$false)]
        [hashtable]$Parameters
    )

    $connection = $null

    try {
        $connection = New-BEPOZDatabaseConnection

        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 60

        if ($Parameters) {
            foreach ($key in $Parameters.Keys) {
                $value = $Parameters[$key]
                if ($null -eq $value) {
                    $value = [DBNull]::Value
                }
                $command.Parameters.AddWithValue("@$key", $value) | Out-Null
            }
        }

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        $dataset = New-Object System.Data.DataSet
        $rowCount = $adapter.Fill($dataset)

        Write-BEPOZLog -Message "Query executed successfully. Rows returned: $rowCount" -Level Info

        return $dataset.Tables[0]
    }
    catch {
        Write-BEPOZLog -Message "Database query failed: $_" -Level Error
        Write-BEPOZLog -Message "Query: $Query" -Level Error
        throw
    }
    finally {
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
            $connection.Dispose()
        }
    }
}

# Read registry value with error handling
function Get-BEPOZRegistryValue {
    <#
    .SYNOPSIS
        Reads Windows Registry value with error handling

    .DESCRIPTION
        Safely reads a registry value with comprehensive error handling

    .PARAMETER Path
        Full registry path (e.g., HKLM:\SOFTWARE\BEPOZ\Config)

    .PARAMETER Name
        Name of the registry value to read

    .EXAMPLE
        $value = Get-BEPOZRegistryValue -Path "HKLM:\SOFTWARE\BEPOZ\Config" -Name "SomeSetting"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    try {
        if (-not (Test-Path $Path)) {
            throw "Registry path not found: $Path"
        }

        $property = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        $value = $property.$Name

        Write-BEPOZLog -Message "Retrieved registry value: $Path\$Name" -Level Info
        return $value
    }
    catch {
        Write-BEPOZLog -Message "Failed to read registry value $Path\$Name: $_" -Level Error
        throw
    }
}

# Write structured log entry
function Write-BEPOZLog {
    <#
    .SYNOPSIS
        Writes formatted log entry to console and file

    .DESCRIPTION
        Creates structured log entries with timestamp, level, computer name, and username.
        Writes to both console (with color) and log file.

    .PARAMETER Message
        The log message to write

    .PARAMETER Level
        Log level: Info, Warning, Error, Success

    .EXAMPLE
        Write-BEPOZLog -Message "User created successfully" -Level Success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $computerName = $env:COMPUTERNAME
    $username = $env:USERNAME

    $logEntry = "[$timestamp] [$Level] [$computerName\$username] $Message"

    # Write to console with color
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host $logEntry -ForegroundColor $color

    # Append to log file (global variable set by launcher)
    if ($global:BEPOZLogFile) {
        try {
            Add-Content -Path $global:BEPOZLogFile -Value $logEntry -ErrorAction Stop
        }
        catch {
            Write-Host "WARNING: Failed to write to log file: $_" -ForegroundColor Yellow
        }
    }
}

# Log audit entry to database
function Write-BEPOZAudit {
    <#
    .SYNOPSIS
        Logs audit trail entry to database

    .DESCRIPTION
        Records audit information in the database for compliance and tracking.
        Failure to write audit does not throw exception to avoid stopping script execution.

    .PARAMETER Action
        Description of the action performed

    .PARAMETER Details
        Additional details about the action

    .PARAMETER TargetUser
        User account affected by the action (if applicable)

    .EXAMPLE
        Write-BEPOZAudit -Action "User Created" -Details "Standard user account" -TargetUser "jdoe"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Details = "",

        [Parameter(Mandatory=$false)]
        [string]$TargetUser = ""
    )

    $query = @"
INSERT INTO AuditLog (Timestamp, ComputerName, Username, Action, Details, TargetUser)
VALUES (GETDATE(), @ComputerName, @Username, @Action, @Details, @TargetUser)
"@

    $params = @{
        ComputerName = $env:COMPUTERNAME
        Username = $env:USERNAME
        Action = $Action
        Details = $Details
        TargetUser = $TargetUser
    }

    try {
        Invoke-BEPOZDatabaseQuery -Query $query -Parameters $params
        Write-BEPOZLog -Message "Audit logged: $Action" -Level Info
    }
    catch {
        Write-BEPOZLog -Message "Failed to write audit log: $_" -Level Warning
        # Don't throw - audit failure shouldn't stop script execution
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-BEPOZDatabaseConfig',
    'New-BEPOZDatabaseConnection',
    'Invoke-BEPOZDatabaseQuery',
    'Get-BEPOZRegistryValue',
    'Write-BEPOZLog',
    'Write-BEPOZAudit'
)
