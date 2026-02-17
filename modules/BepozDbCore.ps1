<#
.SYNOPSIS
    BepozDbCore - Core database access functions for Bepoz PowerShell tools
.DESCRIPTION
    Production-ready module for Bepoz SQL Server database access
    - Registry-based discovery (HKCU:\SOFTWARE\Backoffice)
    - Windows Integrated Security
    - DataTable return pattern (prevents "Rows property not found" errors)
    - Parameterized queries
    - Defensive error handling
.NOTES
    Version: 1.3.0
    Author: Bepoz Support Team
    Last Updated: 2026-02-11

    Critical Patterns:
    - Always returns System.Data.DataTable from queries
    - Uses Write-Output -NoEnumerate to prevent PowerShell unwrapping
    - Registry paths quoted for Constrained Language Mode compatibility
    - Never concatenates user input into SQL strings
    - Automatically logs all queries if BepozLogger module is loaded
#>

#requires -Version 5.1

#region Discovery Functions
function Get-BepozDatabaseConfig {
    <#
    .SYNOPSIS
        Discovers SQL Server instance and database name from Bepoz registry
    .DESCRIPTION
        Reads HKCU:\SOFTWARE\Backoffice for SQL_Server and SQL_DSN values
        This is the ONLY source of truth for database connection info
    .OUTPUTS
        PSCustomObject with SqlServer and Database properties, or $null on failure
    .EXAMPLE
        $config = Get-BepozDatabaseConfig
        if ($config) {
            Write-Host "Connecting to: $($config.SqlServer)\$($config.Database)"
        }
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $regPath = 'HKCU:\SOFTWARE\Backoffice'

    # Validate registry path exists
    if (-not (Test-Path -Path $regPath)) {
        Write-Error "Bepoz registry path not found: $regPath"
        return $null
    }

    try {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop

        $sqlServer = $props.SQL_Server
        $sqlDb = $props.SQL_DSN

        # Validate values are not empty
        if ([string]::IsNullOrWhiteSpace($sqlServer)) {
            Write-Error "Missing registry value: $regPath\SQL_Server"
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($sqlDb)) {
            Write-Error "Missing registry value: $regPath\SQL_DSN"
            return $null
        }

        # Return configuration object
        return [PSCustomObject]@{
            SqlServer = $sqlServer
            Database  = $sqlDb
            Registry  = $regPath
            User      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        }

    } catch {
        Write-Error "Failed to read Bepoz registry: $($_.Exception.Message)"
        return $null
    }
}

function Get-BepozConnectionString {
    <#
    .SYNOPSIS
        Builds SQL Server connection string for Bepoz database
    .DESCRIPTION
        Uses Windows Integrated Security (no username/password needed)
        Includes TrustServerCertificate for common TLS scenarios
    .OUTPUTS
        String connection string, or $null on failure
    .EXAMPLE
        $connStr = Get-BepozConnectionString
        if ($connStr) {
            $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        }
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param()

    $config = Get-BepozDatabaseConfig
    if (-not $config) {
        return $null
    }

    $connStr = "Server=$($config.SqlServer);Database=$($config.Database);Integrated Security=True;TrustServerCertificate=True;Application Name=BepozToolkit;"

    return $connStr
}
#endregion

#region Query Functions
function Invoke-BepozQuery {
    <#
    .SYNOPSIS
        Executes a SQL SELECT query against Bepoz database
    .DESCRIPTION
        Returns System.Data.DataTable with query results
        Uses Write-Output -NoEnumerate to prevent PowerShell from unwrapping single-row results
        CRITICAL: Always returns DataTable, never Object[] or DataRow[]
    .PARAMETER Query
        SQL SELECT statement to execute
    .PARAMETER Parameters
        Hashtable of SQL parameters (e.g., @{"@VenueID" = 1; "@Name" = "Test"})
    .PARAMETER Timeout
        Command timeout in seconds (default: 30)
    .OUTPUTS
        System.Data.DataTable with query results, or $null on failure
    .EXAMPLE
        $venues = Invoke-BepozQuery -Query "SELECT VenueID, Name FROM dbo.Venue WHERE Active = 1"
        foreach ($row in $venues.Rows) {
            Write-Host "$($row.VenueID): $($row.Name)"
        }
    .EXAMPLE
        $params = @{"@VenueID" = 5}
        $result = Invoke-BepozQuery -Query "SELECT * FROM dbo.Venue WHERE VenueID = @VenueID" -Parameters $params
    #>

    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    $connStr = Get-BepozConnectionString
    if (-not $connStr) {
        Write-Error "Failed to build connection string"
        return $null
    }

    $conn = $null
    $cmd = $null
    $adapter = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Create connection
        $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        $conn.Open()

        # Create command
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)
        $cmd.CommandTimeout = $Timeout

        # Add parameters (prevents SQL injection)
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                [void]$cmd.Parameters.AddWithValue($key, [DBNull]::Value)
            } else {
                [void]$cmd.Parameters.AddWithValue($key, $value)
            }
        }

        # Execute query and fill DataTable
        $dt = New-Object System.Data.DataTable
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$adapter.Fill($dt)

        $stopwatch.Stop()

        # Log query if BepozLogger is available
        if (Get-Command -Name Write-BepozLogQuery -ErrorAction SilentlyContinue) {
            Write-BepozLogQuery -Query $Query -Parameters $Parameters -DurationMs $stopwatch.ElapsedMilliseconds -RowCount $dt.Rows.Count
        }

        # CRITICAL: Use -NoEnumerate to prevent PowerShell from unwrapping DataTable
        # Without this, single-row results become DataRow instead of DataTable
        Write-Output -NoEnumerate $dt

    } catch [System.Data.SqlClient.SqlException] {
        $ex = $_.Exception
        Write-Error ("SQL Error {0} (State {1}): {2}" -f $ex.Number, $ex.State, $ex.Message)
        if ($ex.Procedure) {
            Write-Error ("  In procedure: {0} (Line {1})" -f $ex.Procedure, $ex.LineNumber)
        }
        return $null

    } catch {
        Write-Error "Query failed: $($_.Exception.Message)"
        return $null

    } finally {
        if ($adapter) { $adapter.Dispose() }
        if ($cmd) { $cmd.Dispose() }
        if ($conn) { $conn.Close(); $conn.Dispose() }
    }
}

function Invoke-BepozNonQuery {
    <#
    .SYNOPSIS
        Executes a SQL non-query command (INSERT, UPDATE, DELETE) against Bepoz database
    .DESCRIPTION
        Returns the number of rows affected, or -1 on error
        Use for data modification commands only (not SELECT)
    .PARAMETER Query
        SQL command to execute (INSERT, UPDATE, DELETE)
    .PARAMETER Parameters
        Hashtable of SQL parameters
    .PARAMETER Timeout
        Command timeout in seconds (default: 30)
    .OUTPUTS
        Int32 - Number of rows affected, or -1 on failure
    .EXAMPLE
        $params = @{"@VenueID" = 5; "@Name" = "Updated Name"}
        $affected = Invoke-BepozNonQuery -Query "UPDATE dbo.Venue SET Name = @Name WHERE VenueID = @VenueID" -Parameters $params
        Write-Host "Updated $affected rows"
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    $connStr = Get-BepozConnectionString
    if (-not $connStr) {
        Write-Error "Failed to build connection string"
        return -1
    }

    $conn = $null
    $cmd = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Create connection
        $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        $conn.Open()

        # Create command
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)
        $cmd.CommandTimeout = $Timeout

        # Add parameters
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                [void]$cmd.Parameters.AddWithValue($key, [DBNull]::Value)
            } else {
                [void]$cmd.Parameters.AddWithValue($key, $value)
            }
        }

        # Execute non-query
        $rowsAffected = $cmd.ExecuteNonQuery()
        $stopwatch.Stop()

        # Log query if BepozLogger is available
        if (Get-Command -Name Write-BepozLogQuery -ErrorAction SilentlyContinue) {
            Write-BepozLogQuery -Query $Query -Parameters $Parameters -DurationMs $stopwatch.ElapsedMilliseconds -RowCount $rowsAffected
        }

        return $rowsAffected

    } catch [System.Data.SqlClient.SqlException] {
        $ex = $_.Exception
        Write-Error ("SQL Error {0} (State {1}): {2}" -f $ex.Number, $ex.State, $ex.Message)
        if ($ex.Procedure) {
            Write-Error ("  In procedure: {0} (Line {1})" -f $ex.Procedure, $ex.LineNumber)
        }
        return -1

    } catch {
        Write-Error "Command failed: $($_.Exception.Message)"
        return -1

    } finally {
        if ($cmd) { $cmd.Dispose() }
        if ($conn) { $conn.Close(); $conn.Dispose() }
    }
}
#endregion

#region Stored Procedure Functions
function Invoke-BepozStoredProc {
    <#
    .SYNOPSIS
        Executes a stored procedure and returns results as DataTable
    .DESCRIPTION
        Calls a stored procedure with parameters and returns result set
        Supports output parameters and return values
    .PARAMETER ProcedureName
        Name of the stored procedure (e.g., "dbo.MyProcedure")
    .PARAMETER Parameters
        Hashtable of SQL parameters
    .PARAMETER Timeout
        Command timeout in seconds (default: 30)
    .OUTPUTS
        System.Data.DataTable with results, or $null on failure
    .EXAMPLE
        $params = @{"@VenueID" = 1}
        $result = Invoke-BepozStoredProc -ProcedureName "dbo.GetVenueDetails" -Parameters $params
    #>

    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcedureName,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    $connStr = Get-BepozConnectionString
    if (-not $connStr) {
        Write-Error "Failed to build connection string"
        return $null
    }

    $conn = $null
    $cmd = $null
    $adapter = $null

    try {
        # Create connection
        $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        $conn.Open()

        # Create command
        $cmd = New-Object System.Data.SqlClient.SqlCommand($ProcedureName, $conn)
        $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
        $cmd.CommandTimeout = $Timeout

        # Add parameters
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                [void]$cmd.Parameters.AddWithValue($key, [DBNull]::Value)
            } else {
                [void]$cmd.Parameters.AddWithValue($key, $value)
            }
        }

        # Execute and fill DataTable
        $dt = New-Object System.Data.DataTable
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$adapter.Fill($dt)

        # CRITICAL: Use -NoEnumerate
        Write-Output -NoEnumerate $dt

    } catch [System.Data.SqlClient.SqlException] {
        $ex = $_.Exception
        Write-Error ("SQL Error {0} (State {1}): {2}" -f $ex.Number, $ex.State, $ex.Message)
        if ($ex.Procedure) {
            Write-Error ("  In procedure: {0} (Line {1})" -f $ex.Procedure, $ex.LineNumber)
        }
        return $null

    } catch {
        Write-Error "Stored procedure failed: $($_.Exception.Message)"
        return $null

    } finally {
        if ($adapter) { $adapter.Dispose() }
        if ($cmd) { $cmd.Dispose() }
        if ($conn) { $conn.Close(); $conn.Dispose() }
    }
}
#endregion

#region Validation Functions
function Test-BepozDatabaseConnection {
    <#
    .SYNOPSIS
        Tests connectivity to Bepoz database
    .DESCRIPTION
        Attempts to open connection and run simple query
        Returns $true if successful, $false otherwise
    .OUTPUTS
        Boolean indicating connection success
    .EXAMPLE
        if (Test-BepozDatabaseConnection) {
            Write-Host "Database connection OK"
        } else {
            Write-Host "Cannot connect to database"
        }
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $result = Invoke-BepozQuery -Query "SELECT 1 AS TestValue" -Timeout 5

        if ($null -eq $result) {
            return $false
        }

        if ($result.Rows.Count -eq 1 -and $result.Rows[0].TestValue -eq 1) {
            return $true
        }

        return $false

    } catch {
        Write-Error "Connection test failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-BepozDbInfo {
    <#
    .SYNOPSIS
        Gets comprehensive database information including connection string
    .DESCRIPTION
        Wrapper function that combines Get-BepozDatabaseConfig and Get-BepozConnectionString
        Returns a single object with all database info needed by tools
    .PARAMETER ApplicationName
        Optional application name to include in connection string
    .OUTPUTS
        PSCustomObject with Server, Database, ConnectionString, User, and Registry properties
    .EXAMPLE
        $dbInfo = Get-BepozDbInfo -ApplicationName "MyTool"
        Write-Host "Connecting to: $($dbInfo.Server)\$($dbInfo.Database)"
        $data = Invoke-BepozQuery -ConnectionString $dbInfo.ConnectionString -Query $sql
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ApplicationName = "BepozToolkit"
    )

    try {
        # Get config (server, database, etc.)
        $config = Get-BepozDatabaseConfig
        if (-not $config) {
            Write-Error "Failed to get database configuration"
            return $null
        }

        # Build connection string with custom app name
        $connStr = "Server=$($config.SqlServer);Database=$($config.Database);Integrated Security=True;TrustServerCertificate=True;Application Name=$ApplicationName;"

        # Return comprehensive info object
        return [PSCustomObject]@{
            Server           = $config.SqlServer
            Database         = $config.Database
            ConnectionString = $connStr
            User             = $config.User
            Registry         = $config.Registry
            ApplicationName  = $ApplicationName
        }

    } catch {
        Write-Error "Failed to get database info: $($_.Exception.Message)"
        return $null
    }
}
#endregion

#region Module Initialization
# Export functions
Export-ModuleMember -Function @(
    'Get-BepozDatabaseConfig',
    'Get-BepozConnectionString',
    'Get-BepozDbInfo',
    'Invoke-BepozQuery',
    'Invoke-BepozNonQuery',
    'Invoke-BepozStoredProc',
    'Test-BepozDatabaseConnection'
)

# Display load message if run interactively
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "[BepozDbCore v1.3.0] Module loaded successfully" -ForegroundColor Green
}
#endregion
