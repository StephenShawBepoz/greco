<#
.SYNOPSIS
    Bulk Add Operators to BEPOZ Database
.DESCRIPTION
    Add multiple operators from CSV file to a specific parent group
    - Auto-generates 4-digit OpNumber if not provided
    - Creates new operators OR updates existing ones
    - Validates unique OpNumber
.NOTES
    Version: 1.0.0
    Author: BEPOZ IT Team
    Last Updated: 2026-02-17
    Requires Admin: No
#>

Write-BepozLog -Message "=== Bulk Add Operators Started ===" -Level INFO

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    # Get database configuration
    Write-BepozLog -Message "Getting database configuration..." -Level INFO
    $dbConfig = Get-BepozDatabaseConfig
    if (-not $dbConfig) {
        Write-Host "ERROR: Could not get database configuration" -ForegroundColor Red
        exit 1
    }

    $connectionString = Get-BepozConnectionString

    # Test connection
    if (-not (Test-BepozDatabaseConnection)) {
        Write-Host "ERROR: Could not connect to database" -ForegroundColor Red
        exit 1
    }

    Write-BepozLog -Message "Database connection successful" -Level SUCCESS

    # ═══════════════════════════════════════════════════════════
    # LOAD PARENT GROUPS
    # ═══════════════════════════════════════════════════════════

    $query = "SELECT OperatorID, FirstName, LastName, IsParent FROM dbo.Operator WHERE IsParent IN (1, 2) ORDER BY IsParent DESC, FirstName, LastName"
    $parentGroups = Invoke-BepozQuery -Query $query

    if ($parentGroups.Rows.Count -eq 0) {
        Write-Host "ERROR: No parent groups found in database" -ForegroundColor Red
        exit 1
    }

    # ═══════════════════════════════════════════════════════════
    # CREATE MAIN FORM
    # ═══════════════════════════════════════════════════════════

    $form = New-BepozForm -Title "Bulk Add Operators" -Width 900 -Height 700

    # Title
    $lblTitle = New-BepozLabel -Text "Bulk Add Operators" -X 20 -Y 20 -Width 860 -Height 30 -FontSize 16 -Bold
    $form.Controls.Add($lblTitle)

    # ─────────────────────────────────────────────────────────
    # SELECT PARENT GROUP
    # ─────────────────────────────────────────────────────────

    $lblParent = New-BepozLabel -Text "Select Parent Group:" -X 20 -Y 60 -Width 200 -Height 20
    $form.Controls.Add($lblParent)

    $cmbParent = New-Object System.Windows.Forms.ComboBox
    $cmbParent.Location = New-Object System.Drawing.Point(220, 58)
    $cmbParent.Size = New-Object System.Drawing.Size(400, 25)
    $cmbParent.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbParent.Font = (Get-BepozFont -Size 10)
    $cmbParent.BackColor = [System.Drawing.Color]::White

    foreach ($row in $parentGroups.Rows) {
        $typeLabel = if ([int]$row.IsParent -eq 2) { "[BASE]" } else { "[GROUP]" }
        $displayText = "$typeLabel $($row.FirstName) $($row.LastName) (ID: $($row.OperatorID))"
        $item = [PSCustomObject]@{
            Display = $displayText
            OperatorID = [int]$row.OperatorID
        }
        $cmbParent.Items.Add($item) | Out-Null
    }
    $cmbParent.DisplayMember = "Display"

    if ($cmbParent.Items.Count -gt 0) {
        $cmbParent.SelectedIndex = 0
    }

    $form.Controls.Add($cmbParent)

    # ─────────────────────────────────────────────────────────
    # CSV FILE SELECTION
    # ─────────────────────────────────────────────────────────

    $lblCsv = New-BepozLabel -Text "CSV File:" -X 20 -Y 100 -Width 200 -Height 20
    $form.Controls.Add($lblCsv)

    $txtCsvPath = New-BepozTextBox -X 220 -Y 98 -Width 400 -Height 25
    $txtCsvPath.ReadOnly = $true
    $form.Controls.Add($txtCsvPath)

    $btnBrowse = New-BepozButton -Text "Browse..." -X 630 -Y 96 -Width 100 -Height 30
    $btnBrowse.Add_Click({
        $filePicker = Show-BepozFilePicker -Title "Select CSV File" -Filter "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        if ($filePicker) {
            $txtCsvPath.Text = $filePicker
            Write-BepozLogAction "Selected CSV file: $filePicker"
        }
    })
    $form.Controls.Add($btnBrowse)

    # CSV Format Help
    $lblCsvFormat = New-BepozLabel -Text "CSV Format: FirstName,LastName,OpNumber,Password (OpNumber & Password optional)" -X 220 -Y 128 -Width 660 -Height 20
    $lblCsvFormat.ForeColor = (Get-BepozColor -Name "Gray")
    $lblCsvFormat.Font = (Get-BepozFont -Size 8)
    $form.Controls.Add($lblCsvFormat)

    # ─────────────────────────────────────────────────────────
    # OPTIONS
    # ─────────────────────────────────────────────────────────

    $chkUpdateExisting = New-Object System.Windows.Forms.CheckBox
    $chkUpdateExisting.Location = New-Object System.Drawing.Point(220, 155)
    $chkUpdateExisting.Size = New-Object System.Drawing.Size(400, 20)
    $chkUpdateExisting.Text = "Update existing operators if OpNumber exists"
    $chkUpdateExisting.Font = (Get-BepozFont -Size 10)
    $chkUpdateExisting.Checked = $false
    $form.Controls.Add($chkUpdateExisting)

    $chkUseParentSettings = New-Object System.Windows.Forms.CheckBox
    $chkUseParentSettings.Location = New-Object System.Drawing.Point(220, 180)
    $chkUseParentSettings.Size = New-Object System.Drawing.Size(400, 20)
    $chkUseParentSettings.Text = "Use Parent Settings (inherit permissions from group)"
    $chkUseParentSettings.Font = (Get-BepozFont -Size 10)
    $chkUseParentSettings.Checked = $true
    $form.Controls.Add($chkUseParentSettings)

    # ─────────────────────────────────────────────────────────
    # LOAD BUTTON
    # ─────────────────────────────────────────────────────────

    $btnLoad = New-BepozButton -Text "Load CSV" -X 750 -Y 96 -Width 110 -Height 30 -Primary
    $btnLoad.Add_Click({
        if ([string]::IsNullOrWhiteSpace($txtCsvPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a CSV file first", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        if (-not (Test-Path $txtCsvPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show("CSV file not found", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        try {
            Write-BepozLogAction "Loading CSV file: $($txtCsvPath.Text)"

            $csvData = Import-Csv -Path $txtCsvPath.Text
            $dgvOperators.Rows.Clear()

            foreach ($row in $csvData) {
                # Validate required fields
                if ([string]::IsNullOrWhiteSpace($row.FirstName) -or [string]::IsNullOrWhiteSpace($row.LastName)) {
                    continue
                }

                # Auto-generate OpNumber if not provided
                $opNumber = $row.OpNumber
                if ([string]::IsNullOrWhiteSpace($opNumber)) {
                    $opNumber = Get-Random -Minimum 1000 -Maximum 9999
                    $opNumber = $opNumber.ToString().PadLeft(4, '0')
                }

                # Default password if not provided
                $password = $row.Password
                if ([string]::IsNullOrWhiteSpace($password)) {
                    $password = "1234"
                }

                $dgvOperators.Rows.Add($row.FirstName, $row.LastName, $opNumber, $password, "Pending", "") | Out-Null
            }

            Write-BepozLog -Message "Loaded $($dgvOperators.Rows.Count) operators from CSV" -Level INFO
            [System.Windows.Forms.MessageBox]::Show("Loaded $($dgvOperators.Rows.Count) operators from CSV", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            Write-BepozLogError -Message "Failed to load CSV" -Exception $_.Exception
            [System.Windows.Forms.MessageBox]::Show("Failed to load CSV: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $form.Controls.Add($btnLoad)

    # ─────────────────────────────────────────────────────────
    # OPERATORS DATA GRID
    # ─────────────────────────────────────────────────────────

    $dgvOperators = New-BepozDataGridView -X 20 -Y 220 -Width 840 -Height 350
    $dgvOperators.Columns.Add("FirstName", "First Name") | Out-Null
    $dgvOperators.Columns.Add("LastName", "Last Name") | Out-Null
    $dgvOperators.Columns.Add("OpNumber", "Op Number") | Out-Null
    $dgvOperators.Columns.Add("Password", "Password") | Out-Null
    $dgvOperators.Columns.Add("Status", "Status") | Out-Null
    $dgvOperators.Columns.Add("Message", "Message") | Out-Null

    $dgvOperators.Columns[0].Width = 150
    $dgvOperators.Columns[1].Width = 150
    $dgvOperators.Columns[2].Width = 100
    $dgvOperators.Columns[3].Width = 100
    $dgvOperators.Columns[4].Width = 100
    $dgvOperators.Columns[5].Width = 220

    $form.Controls.Add($dgvOperators)

    # ─────────────────────────────────────────────────────────
    # ACTION BUTTONS
    # ─────────────────────────────────────────────────────────

    $btnExecute = New-BepozButton -Text "Add Operators" -X 670 -Y 590 -Width 190 -Height 40 -Primary
    $btnExecute.Add_Click({
        if ($dgvOperators.Rows.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No operators to add. Please load a CSV file first.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        if ($null -eq $cmbParent.SelectedItem) {
            [System.Windows.Forms.MessageBox]::Show("Please select a parent group", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show("Add $($dgvOperators.Rows.Count) operators to the selected group?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $parentID = $cmbParent.SelectedItem.OperatorID
        $updateExisting = $chkUpdateExisting.Checked
        $useParentSettings = $chkUseParentSettings.Checked

        Write-BepozLogAction "Starting bulk add: $($dgvOperators.Rows.Count) operators to ParentID=$parentID, UpdateExisting=$updateExisting, UseParentSettings=$useParentSettings"

        $successCount = 0
        $errorCount = 0
        $updateCount = 0

        # Get existing OpNumbers to validate uniqueness
        $existingOpNumbers = Invoke-BepozQuery -Query "SELECT OpNumber FROM dbo.Operator WHERE OpNumber <> ''"
        $existingOpNumberList = @()
        foreach ($row in $existingOpNumbers.Rows) {
            $existingOpNumberList += $row.OpNumber
        }

        foreach ($dgvRow in $dgvOperators.Rows) {
            try {
                $firstName = $dgvRow.Cells[0].Value
                $lastName = $dgvRow.Cells[1].Value
                $opNumber = $dgvRow.Cells[2].Value
                $password = $dgvRow.Cells[3].Value

                # Validate OpNumber is 4 digits
                if ($opNumber -notmatch '^\d{4}$') {
                    # Regenerate if invalid
                    do {
                        $opNumber = Get-Random -Minimum 1000 -Maximum 9999
                        $opNumber = $opNumber.ToString().PadLeft(4, '0')
                    } while ($existingOpNumberList -contains $opNumber)
                }

                # Check if OpNumber already exists
                $checkQuery = "SELECT OperatorID FROM dbo.Operator WHERE OpNumber = @OpNumber"
                $existing = Invoke-BepozQuery -Query $checkQuery -Parameters @{ OpNumber = $opNumber }

                if ($existing.Rows.Count -gt 0) {
                    if ($updateExisting) {
                        # Update existing operator
                        $operatorID = $existing.Rows[0].OperatorID
                        $updateQuery = "UPDATE dbo.Operator SET FirstName = @FirstName, LastName = @LastName, Password = @Password, ParentID = @ParentID, UseParentSettings = @UseParentSettings, DateUpdated = GETDATE() WHERE OperatorID = @OperatorID"
                        $params = @{
                            OperatorID = $operatorID
                            FirstName = $firstName
                            LastName = $lastName
                            Password = $password
                            ParentID = $parentID
                            UseParentSettings = $useParentSettings
                        }
                        Invoke-BepozNonQuery -Query $updateQuery -Parameters $params | Out-Null

                        $dgvRow.Cells[4].Value = "Updated"
                        $dgvRow.Cells[5].Value = "Updated existing OpNumber $opNumber"
                        $updateCount++
                        Write-BepozLog -Message "Updated operator: $firstName $lastName (OpNumber: $opNumber)" -Level INFO
                    }
                    else {
                        $dgvRow.Cells[4].Value = "Skipped"
                        $dgvRow.Cells[5].Value = "OpNumber $opNumber already exists"
                        $errorCount++
                        Write-BepozLog -Message "Skipped duplicate OpNumber: $opNumber" -Level WARN
                    }
                }
                else {
                    # Insert new operator
                    $insertQuery = @"
INSERT INTO dbo.Operator (
    FirstName, LastName, OpNumber, Password, ParentID, IsParent,
    UseParentSettings, Inactive, DateUpdated, DateTimeCreated,
    AddressID, CommentId, AllowedVenueID
) VALUES (
    @FirstName, @LastName, @OpNumber, @Password, @ParentID, 0,
    @UseParentSettings, 0, GETDATE(), GETDATE(),
    0, 0, 0
)
"@
                    $params = @{
                        FirstName = $firstName
                        LastName = $lastName
                        OpNumber = $opNumber
                        Password = $password
                        ParentID = $parentID
                        UseParentSettings = $useParentSettings
                    }
                    Invoke-BepozNonQuery -Query $insertQuery -Parameters $params | Out-Null

                    $existingOpNumberList += $opNumber

                    $dgvRow.Cells[4].Value = "Success"
                    $dgvRow.Cells[5].Value = "Added successfully"
                    $successCount++
                    Write-BepozLog -Message "Created operator: $firstName $lastName (OpNumber: $opNumber)" -Level SUCCESS
                }
            }
            catch {
                $dgvRow.Cells[4].Value = "Error"
                $dgvRow.Cells[5].Value = $_.Exception.Message
                $errorCount++
                Write-BepozLogError -Message "Failed to add operator: $firstName $lastName" -Exception $_.Exception
            }

            $dgvOperators.Refresh()
        }

        Write-BepozLog -Message "Bulk add complete: $successCount added, $updateCount updated, $errorCount errors" -Level SUCCESS
        [System.Windows.Forms.MessageBox]::Show("Complete!`n`nAdded: $successCount`nUpdated: $updateCount`nErrors: $errorCount", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $form.Controls.Add($btnExecute)

    $btnClose = New-BepozButton -Text "Close" -X 20 -Y 590 -Width 120 -Height 40
    $btnClose.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($btnClose)

    # ═══════════════════════════════════════════════════════════
    # SHOW FORM
    # ═══════════════════════════════════════════════════════════

    Write-BepozLog -Message "Displaying Bulk Add Operators form" -Level INFO
    $form.ShowDialog() | Out-Null

    Write-BepozLog -Message "Script completed successfully" -Level SUCCESS
}
catch {
    Write-Host ""
    Write-Host "ERROR: Script failed" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-BepozLog -Message "Script failed: $_" -Level ERROR
    Write-BepozLog -Message $_.ScriptStackTrace -Level ERROR
    throw
}

Write-BepozLog -Message "=== Bulk Add Operators Ended ===" -Level INFO
