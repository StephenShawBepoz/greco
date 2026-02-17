<#
.SYNOPSIS
    BepozUI - Common Windows Forms UI helpers for toolkit tools
.DESCRIPTION
    Reduces repetitive Windows Forms code in GUI tools
    - Progress dialogs with auto-close
    - Input dialogs (text, number, dropdown)
    - File/folder pickers
    - Confirmation dialogs
    - Data grids with sorting
    - Message boxes (enhanced)
    - Form builders
.NOTES
    Version: 1.0.0
    Author: Bepoz Support Team
    Last Updated: 2026-02-11

    Typical savings: 30-40% reduction in GUI tool code
#>

#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Progress Dialogs

function Show-BepozProgressDialog {
    <#
    .SYNOPSIS
        Shows a progress dialog with optional auto-close
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Progress message
    .PARAMETER AutoClose
        Auto-close after specified seconds (0 = manual close)
    .OUTPUTS
        Form object (call .Close() to close manually)
    .EXAMPLE
        $progress = Show-BepozProgressDialog -Title "Loading" -Message "Please wait..."
        # Do work
        $progress.Close()
    .EXAMPLE
        Show-BepozProgressDialog -Title "Success" -Message "Done!" -AutoClose 2
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [int]$AutoClose = 0
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ControlBox = ($AutoClose -eq 0)
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Location = New-Object System.Drawing.Point(20, 30)
    $label.Size = New-Object System.Drawing.Size(360, 60)
    $label.TextAlign = "MiddleCenter"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($label)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 90)
    $progressBar.Size = New-Object System.Drawing.Size(360, 20)
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 30
    $form.Controls.Add($progressBar)

    if ($AutoClose -gt 0) {
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = ($AutoClose * 1000)
        $timer.Add_Tick({
            $form.Close()
            $timer.Stop()
            $timer.Dispose()
        })
        $timer.Start()
    }

    $form.Show()
    $form.Refresh()

    return $form
}

function Update-BepozProgressDialog {
    <#
    .SYNOPSIS
        Updates an existing progress dialog message
    .PARAMETER Form
        Progress dialog form object
    .PARAMETER Message
        New message
    .EXAMPLE
        $progress = Show-BepozProgressDialog -Title "Processing" -Message "Step 1..."
        Update-BepozProgressDialog -Form $progress -Message "Step 2..."
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Form]$Form,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $label = $Form.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
    if ($label) {
        $label.Text = $Message
        $Form.Refresh()
    }
}

#endregion

#region Input Dialogs

function Show-BepozInputDialog {
    <#
    .SYNOPSIS
        Shows an input dialog for text entry
    .PARAMETER Title
        Dialog title
    .PARAMETER Prompt
        Prompt text
    .PARAMETER DefaultValue
        Default input value
    .PARAMETER Multiline
        Allow multiline input
    .OUTPUTS
        String - User input, or $null if cancelled
    .EXAMPLE
        $name = Show-BepozInputDialog -Title "Name" -Prompt "Enter workstation name:"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$DefaultValue = "",

        [Parameter(Mandatory = $false)]
        [switch]$Multiline
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400, $(if ($Multiline) { 300 } else { 180 }))
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(380, 40)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(10, 50)
    $textbox.Size = New-Object System.Drawing.Size(370, $(if ($Multiline) { 150 } else { 20 }))
    $textbox.Text = $DefaultValue
    $textbox.Multiline = $Multiline
    if ($Multiline) {
        $textbox.ScrollBars = "Vertical"
    }
    $form.Controls.Add($textbox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(210, $(if ($Multiline) { 210 } else { 90 }))
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(300, $(if ($Multiline) { 210 } else { 90 }))
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $textbox.Text
    }

    return $null
}

function Show-BepozNumberDialog {
    <#
    .SYNOPSIS
        Shows an input dialog for numeric entry with validation
    .PARAMETER Title
        Dialog title
    .PARAMETER Prompt
        Prompt text
    .PARAMETER DefaultValue
        Default number
    .PARAMETER Minimum
        Minimum allowed value
    .PARAMETER Maximum
        Maximum allowed value
    .OUTPUTS
        Int32 - User input, or $null if cancelled
    .EXAMPLE
        $count = Show-BepozNumberDialog -Title "Count" -Prompt "How many?" -Minimum 1 -Maximum 100
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [int]$DefaultValue = 0,

        [Parameter(Mandatory = $false)]
        [int]$Minimum = 0,

        [Parameter(Mandatory = $false)]
        [int]$Maximum = 999999
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(350, 180)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(330, 40)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($label)

    $numericUpDown = New-Object System.Windows.Forms.NumericUpDown
    $numericUpDown.Location = New-Object System.Drawing.Point(10, 50)
    $numericUpDown.Size = New-Object System.Drawing.Size(320, 20)
    $numericUpDown.Minimum = $Minimum
    $numericUpDown.Maximum = $Maximum
    $numericUpDown.Value = $DefaultValue
    $form.Controls.Add($numericUpDown)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(160, 90)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(250, 90)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return [int]$numericUpDown.Value
    }

    return $null
}

function Show-BepozDropdownDialog {
    <#
    .SYNOPSIS
        Shows a dialog with a dropdown selection
    .PARAMETER Title
        Dialog title
    .PARAMETER Prompt
        Prompt text
    .PARAMETER Options
        Array of options to display
    .PARAMETER DefaultIndex
        Default selected index
    .OUTPUTS
        String - Selected option, or $null if cancelled
    .EXAMPLE
        $venue = Show-BepozDropdownDialog -Title "Venue" -Prompt "Select venue:" -Options @("Venue 1", "Venue 2")
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $true)]
        [array]$Options,

        [Parameter(Mandatory = $false)]
        [int]$DefaultIndex = 0
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(380, 40)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($label)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(10, 50)
    $comboBox.Size = New-Object System.Drawing.Size(370, 20)
    $comboBox.DropDownStyle = "DropDownList"
    foreach ($option in $Options) {
        [void]$comboBox.Items.Add($option)
    }
    if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $Options.Count) {
        $comboBox.SelectedIndex = $DefaultIndex
    }
    $form.Controls.Add($comboBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(210, 100)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(300, 100)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $comboBox.SelectedItem) {
        return $comboBox.SelectedItem.ToString()
    }

    return $null
}

#endregion

#region File/Folder Pickers

function Show-BepozFilePicker {
    <#
    .SYNOPSIS
        Shows a file open dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Filter
        File filter (e.g., "CSV|*.csv|All|*.*")
    .PARAMETER InitialDirectory
        Starting directory
    .OUTPUTS
        String - Selected file path, or $null if cancelled
    .EXAMPLE
        $file = Show-BepozFilePicker -Title "Select CSV" -Filter "CSV|*.csv"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "Select File",

        [Parameter(Mandatory = $false)]
        [string]$Filter = "All Files|*.*",

        [Parameter(Mandatory = $false)]
        [string]$InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    )

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.InitialDirectory = $InitialDirectory

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }

    return $null
}

function Show-BepozFileSavePicker {
    <#
    .SYNOPSIS
        Shows a file save dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Filter
        File filter
    .PARAMETER DefaultFileName
        Default file name
    .OUTPUTS
        String - Selected file path, or $null if cancelled
    .EXAMPLE
        $file = Show-BepozFileSavePicker -Title "Save Report" -Filter "CSV|*.csv" -DefaultFileName "report.csv"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "Save File",

        [Parameter(Mandatory = $false)]
        [string]$Filter = "All Files|*.*",

        [Parameter(Mandatory = $false)]
        [string]$DefaultFileName = "",

        [Parameter(Mandatory = $false)]
        [string]$InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    )

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.FileName = $DefaultFileName
    $dialog.InitialDirectory = $InitialDirectory

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }

    return $null
}

function Show-BepozFolderPicker {
    <#
    .SYNOPSIS
        Shows a folder selection dialog
    .PARAMETER Title
        Dialog description
    .OUTPUTS
        String - Selected folder path, or $null if cancelled
    .EXAMPLE
        $folder = Show-BepozFolderPicker -Title "Select backup location"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Title = "Select Folder"
    )

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Title
    $dialog.ShowNewFolderButton = $true

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }

    return $null
}

#endregion

#region Confirmation Dialogs

function Show-BepozConfirmDialog {
    <#
    .SYNOPSIS
        Shows a Yes/No confirmation dialog
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Confirmation message
    .PARAMETER Icon
        Icon type (Question, Warning, Error, Information)
    .OUTPUTS
        Boolean - $true if Yes, $false if No
    .EXAMPLE
        if (Show-BepozConfirmDialog -Title "Confirm" -Message "Delete 150 records?") {
            # User clicked Yes
        }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Question', 'Warning', 'Error', 'Information')]
        [string]$Icon = 'Question'
    )

    $iconEnum = [System.Windows.Forms.MessageBoxIcon]::$Icon
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        $iconEnum
    )

    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Show-BepozMessageBox {
    <#
    .SYNOPSIS
        Shows a message box with OK button
    .PARAMETER Title
        Dialog title
    .PARAMETER Message
        Message text
    .PARAMETER Icon
        Icon type (Information, Warning, Error)
    .EXAMPLE
        Show-BepozMessageBox -Title "Success" -Message "Operation completed!" -Icon Information
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Icon = 'Information'
    )

    $iconEnum = [System.Windows.Forms.MessageBoxIcon]::$Icon
    [void][System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $iconEnum
    )
}

#endregion

#region Data Display

function Show-BepozDataGrid {
    <#
    .SYNOPSIS
        Shows a DataTable in a sortable grid view
    .PARAMETER Title
        Window title
    .PARAMETER Data
        DataTable to display
    .PARAMETER ReadOnly
        Make grid read-only (default true)
    .PARAMETER Width
        Window width (default 800)
    .PARAMETER Height
        Window height (default 600)
    .EXAMPLE
        $venues = Invoke-BepozQuery -Query "SELECT * FROM Venue"
        Show-BepozDataGrid -Title "Venues" -Data $venues
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [System.Data.DataTable]$Data,

        [Parameter(Mandatory = $false)]
        [bool]$ReadOnly = $true,

        [Parameter(Mandatory = $false)]
        [int]$Width = 800,

        [Parameter(Mandatory = $false)]
        [int]$Height = 600
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$Title ($($Data.Rows.Count) rows)"
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.StartPosition = "CenterScreen"

    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Dock = "Fill"
    $dataGrid.DataSource = $Data
    $dataGrid.ReadOnly = $ReadOnly
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.AllowUserToDeleteRows = $false
    $dataGrid.SelectionMode = "FullRowSelect"
    $dataGrid.MultiSelect = $true
    $dataGrid.AutoSizeColumnsMode = "AllCells"
    $dataGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray

    $form.Controls.Add($dataGrid)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Close"
    $closeButton.Dock = "Bottom"
    $closeButton.Height = 40
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    [void]$form.ShowDialog()
}

#endregion

#region Module Exports
Export-ModuleMember -Function @(
    'Show-BepozProgressDialog',
    'Update-BepozProgressDialog',
    'Show-BepozInputDialog',
    'Show-BepozNumberDialog',
    'Show-BepozDropdownDialog',
    'Show-BepozFilePicker',
    'Show-BepozFileSavePicker',
    'Show-BepozFolderPicker',
    'Show-BepozConfirmDialog',
    'Show-BepozMessageBox',
    'Show-BepozDataGrid'
)

# Display load message if run interactively
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "[BepozUI v1.0.0] Module loaded successfully" -ForegroundColor Green
}
#endregion
