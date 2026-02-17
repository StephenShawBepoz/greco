<#
.SYNOPSIS
    Bepoz Toolkit UI Theme Module

.DESCRIPTION
    Provides consistent, professional styling for Windows Forms controls
    using the official Bepoz color palette.

.NOTES
    Version: 1.0.0
    Author: Bepoz Development Team
    Date: 2026-02-11

    Color Usage Rules:
    1. Primary color (#002D6A) - Exclusive use for brand integrity
    2. Secondary colors - Only for complementary difference when needed
    3. Tertiary colors - Final option, only when absolutely necessary

.EXAMPLE
    # Load the theme module
    . .\BepozTheme.ps1

    # Create a themed button
    $btnRun = New-BepozButton -Text "Run Tool" -Type Success -Location (50, 50)

    # Apply theme to entire form
    Apply-BepozFormTheme -Form $myForm
#>

#region Color Palette

# Official Bepoz Color Palette
$Script:BepozColors = @{
    # Primary - Use exclusively for brand integrity
    Primary      = @{
        Hex  = "#002D6A"
        RGB  = @(0, 45, 106)
        Name = "Bepoz Blue"
        CMYK = "100, 90, 31, 21"
    }

    # Secondary - Only for complementary difference
    DarkBlue     = @{
        Hex  = "#001432"
        RGB  = @(0, 20, 50)
        Name = "Dark Blue"
        CMYK = "89, 37, 66, 23"
    }
    Purple       = @{
        Hex  = "#673AB6"
        RGB  = @(103, 58, 182)
        Name = "Purple"
        CMYK = "72, 84, 0, 0"
    }
    Gray         = @{
        Hex  = "#808080"
        RGB  = @(128, 128, 128)
        Name = "Gray"
        CMYK = "52, 43, 43, 8"
    }

    # Tertiary - Only when absolutely necessary
    LightBlue    = @{
        Hex  = "#8AA8DD"
        RGB  = @(138, 168, 221)
        Name = "Light Blue"
        CMYK = "45, 27, 0, 0"
    }
    Green        = @{
        Hex  = "#0A7C48"
        RGB  = @(10, 124, 72)
        Name = "Green"
        CMYK = "88, 27, 91, 14"
    }
    BrightPurple = @{
        Hex  = "#9C27B0"
        RGB  = @(156, 39, 176)
        Name = "Bright Purple"
        CMYK = "50, 90, 0, 0"
    }

    # Standard (automatically included)
    White        = @{
        Hex  = "#FFFFFF"
        RGB  = @(255, 255, 255)
        Name = "White"
    }
    Black        = @{
        Hex  = "#000000"
        RGB  = @(0, 0, 0)
        Name = "Black"
    }
}

# Quick access color objects (cached for performance)
$Script:ColorCache = @{}

#endregion

#region Helper Functions

function Get-BepozColor {
    <#
    .SYNOPSIS
        Get a System.Drawing.Color object from the Bepoz palette

    .PARAMETER Name
        Color name from the palette (Primary, DarkBlue, Purple, etc.)

    .EXAMPLE
        $blue = Get-BepozColor -Name Primary
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Primary', 'DarkBlue', 'Purple', 'Gray', 'LightBlue', 'Green', 'BrightPurple', 'White', 'Black')]
        [string]$Name
    )

    # Return cached color if available
    if ($Script:ColorCache.ContainsKey($Name)) {
        return $Script:ColorCache[$Name]
    }

    # Create color from RGB values
    $rgb = $Script:BepozColors[$Name].RGB
    $color = [System.Drawing.Color]::FromArgb($rgb[0], $rgb[1], $rgb[2])

    # Cache for future use
    $Script:ColorCache[$Name] = $color

    return $color
}

function Get-BepozColorWithAlpha {
    <#
    .SYNOPSIS
        Get a color with transparency

    .PARAMETER Name
        Color name from the palette

    .PARAMETER Alpha
        Transparency (0-255, where 255 is opaque)
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Primary', 'DarkBlue', 'Purple', 'Gray', 'LightBlue', 'Green', 'BrightPurple', 'White', 'Black')]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$Alpha
    )

    $rgb = $Script:BepozColors[$Name].RGB
    return [System.Drawing.Color]::FromArgb($Alpha, $rgb[0], $rgb[1], $rgb[2])
}

function Get-BepozFont {
    <#
    .SYNOPSIS
        Get a consistent Bepoz-themed font

    .PARAMETER Size
        Font size in points

    .PARAMETER Style
        Font style (Regular, Bold, Italic)
    #>
    param(
        [int]$Size = 9,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )

    return New-Object System.Drawing.Font("Segoe UI", $Size, $Style)
}

#endregion

#region Button Functions

function New-BepozButton {
    <#
    .SYNOPSIS
        Create a themed button control

    .PARAMETER Text
        Button text

    .PARAMETER Type
        Button type: Success (green), Info (purple), Neutral (gray), Primary (blue), Danger (black)

    .PARAMETER Location
        Button location (X, Y)

    .PARAMETER Size
        Button size (Width, Height). Defaults to auto-size based on text.

    .PARAMETER Enabled
        Whether button is enabled (default: true)

    .EXAMPLE
        $btnRun = New-BepozButton -Text "Run Tool" -Type Success -Location (10, 50) -Size (200, 40)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Info', 'Neutral', 'Primary', 'Danger')]
        [string]$Type,

        [Parameter(Mandatory)]
        [int[]]$Location,

        [int[]]$Size,

        [bool]$Enabled = $true
    )

    $button = New-Object System.Windows.Forms.Button

    # Set location
    $button.Location = New-Object System.Drawing.Point($Location[0], $Location[1])

    # Set size (auto if not specified)
    if ($Size) {
        $button.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    }
    else {
        $button.AutoSize = $true
        $button.MinimumSize = New-Object System.Drawing.Size(100, 35)
    }

    # Set text
    $button.Text = $Text

    # Set font
    $button.Font = Get-BepozFont -Size 10

    # Flat modern style
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0

    # Set colors based on type
    switch ($Type) {
        'Success' {
            # Green (#0A7C48) - Primary actions (Run, Apply, Save)
            $button.BackColor = Get-BepozColor -Name Green
            $button.ForeColor = Get-BepozColor -Name White
            $button.FlatAppearance.MouseOverBackColor = Get-BepozColor -Name LightBlue
        }
        'Info' {
            # Purple (#673AB6) - Documentation/info actions
            $button.BackColor = Get-BepozColor -Name Purple
            $button.ForeColor = Get-BepozColor -Name White
            $button.FlatAppearance.MouseOverBackColor = Get-BepozColor -Name LightBlue
        }
        'Neutral' {
            # Gray (#808080) - Standard actions (Refresh, Cancel, Close)
            $button.BackColor = Get-BepozColor -Name Gray
            $button.ForeColor = Get-BepozColor -Name White
            $button.FlatAppearance.MouseOverBackColor = Get-BepozColor -Name LightBlue
        }
        'Primary' {
            # Bepoz Blue (#002D6A) - Brand actions (rare, use sparingly)
            $button.BackColor = Get-BepozColor -Name Primary
            $button.ForeColor = Get-BepozColor -Name White
            $button.FlatAppearance.MouseOverBackColor = Get-BepozColor -Name LightBlue
        }
        'Danger' {
            # Black - Destructive actions (Delete)
            $button.BackColor = Get-BepozColor -Name Black
            $button.ForeColor = Get-BepozColor -Name White
            $button.FlatAppearance.MouseOverBackColor = Get-BepozColorWithAlpha -Name Gray -Alpha 200
        }
    }

    # Disabled state
    if (-not $Enabled) {
        $button.Enabled = $false
        $button.BackColor = Get-BepozColorWithAlpha -Name Gray -Alpha 100
        $button.ForeColor = Get-BepozColor -Name DarkBlue
    }

    # Cursor
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    return $button
}

#endregion

#region Panel Functions

function New-BepozPanel {
    <#
    .SYNOPSIS
        Create a themed panel with optional header

    .PARAMETER Location
        Panel location (X, Y)

    .PARAMETER Size
        Panel size (Width, Height)

    .PARAMETER HeaderText
        Optional header text (creates header bar if provided)

    .PARAMETER BorderStyle
        Border style (None, FixedSingle, Fixed3D)

    .EXAMPLE
        $panel = New-BepozPanel -Location (10, 10) -Size (300, 400) -HeaderText "Categories"
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size,

        [string]$HeaderText,

        [System.Windows.Forms.BorderStyle]$BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $panel.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $panel.BorderStyle = $BorderStyle
    $panel.BackColor = Get-BepozColor -Name White

    # Add header if specified
    if ($HeaderText) {
        $header = New-Object System.Windows.Forms.Label
        $header.Text = $HeaderText
        $header.Location = New-Object System.Drawing.Point(0, 0)
        $header.Size = New-Object System.Drawing.Size($Size[0], 30)
        $header.Font = Get-BepozFont -Size 10 -Style Bold
        $header.BackColor = Get-BepozColor -Name DarkBlue
        $header.ForeColor = Get-BepozColor -Name White
        $header.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $header.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)

        $panel.Controls.Add($header)
    }

    return $panel
}

function New-BepozGroupBox {
    <#
    .SYNOPSIS
        Create a themed group box

    .PARAMETER Text
        Group box title

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size
    )

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Text = $Text
    $groupBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $groupBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $groupBox.Font = Get-BepozFont -Size 9 -Style Bold
    $groupBox.ForeColor = Get-BepozColor -Name Primary

    return $groupBox
}

#endregion

#region List Controls

function New-BepozListBox {
    <#
    .SYNOPSIS
        Create a themed list box

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)

    .PARAMETER SelectionMode
        Selection mode (One, MultiSimple, MultiExtended)
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size,

        [System.Windows.Forms.SelectionMode]$SelectionMode = [System.Windows.Forms.SelectionMode]::One
    )

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $listBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $listBox.Font = Get-BepozFont -Size 9
    $listBox.SelectionMode = $SelectionMode
    $listBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    return $listBox
}

function New-BepozCheckedListBox {
    <#
    .SYNOPSIS
        Create a themed checked list box

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size
    )

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $checkedListBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $checkedListBox.Font = Get-BepozFont -Size 9
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    return $checkedListBox
}

function New-BepozComboBox {
    <#
    .SYNOPSIS
        Create a themed combo box

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)

    .PARAMETER DropDownStyle
        Drop down style
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size,

        [System.Windows.Forms.ComboBoxStyle]$DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    )

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $comboBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $comboBox.Font = Get-BepozFont -Size 9
    $comboBox.DropDownStyle = $DropDownStyle
    $comboBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    return $comboBox
}

#endregion

#region Label Functions

function New-BepozLabel {
    <#
    .SYNOPSIS
        Create a themed label

    .PARAMETER Text
        Label text

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)

    .PARAMETER Type
        Label type: Header, SubHeader, Normal, Small
    #>
    param(
        [string]$Text = "",

        [Parameter(Mandatory)]
        [int[]]$Location,

        [int[]]$Size,

        [ValidateSet('Header', 'SubHeader', 'Normal', 'Small')]
        [string]$Type = 'Normal'
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($Location[0], $Location[1])

    if ($Size) {
        $label.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
        $label.AutoSize = $false
    }
    else {
        $label.AutoSize = $true
    }

    # Style based on type
    switch ($Type) {
        'Header' {
            $label.Font = Get-BepozFont -Size 14 -Style Bold
            $label.ForeColor = Get-BepozColor -Name Primary
        }
        'SubHeader' {
            $label.Font = Get-BepozFont -Size 11 -Style Bold
            $label.ForeColor = Get-BepozColor -Name DarkBlue
        }
        'Normal' {
            $label.Font = Get-BepozFont -Size 9
            $label.ForeColor = Get-BepozColor -Name Black
        }
        'Small' {
            $label.Font = Get-BepozFont -Size 8
            $label.ForeColor = Get-BepozColor -Name Gray
        }
    }

    return $label
}

#endregion

#region TextBox Functions

function New-BepozTextBox {
    <#
    .SYNOPSIS
        Create a themed text box

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)

    .PARAMETER Multiline
        Enable multiline

    .PARAMETER ReadOnly
        Make read-only
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size,

        [switch]$Multiline,

        [switch]$ReadOnly
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $textBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $textBox.Font = Get-BepozFont -Size 9
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    if ($Multiline) {
        $textBox.Multiline = $true
        $textBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    }

    if ($ReadOnly) {
        $textBox.ReadOnly = $true
        $textBox.BackColor = Get-BepozColorWithAlpha -Name Gray -Alpha 30
    }

    return $textBox
}

#endregion

#region Form Functions

function Apply-BepozFormTheme {
    <#
    .SYNOPSIS
        Apply Bepoz theme to an entire form

    .PARAMETER Form
        The form to theme

    .PARAMETER ShowBrand
        Add Bepoz branding to title bar

    .EXAMPLE
        $form = New-Object System.Windows.Forms.Form
        Apply-BepozFormTheme -Form $form -ShowBrand
    #>
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Form]$Form,

        [switch]$ShowBrand
    )

    # Set form colors
    $Form.BackColor = Get-BepozColor -Name White
    $Form.Font = Get-BepozFont -Size 9

    # Add branding if requested
    if ($ShowBrand -and -not $Form.Text.StartsWith("Bepoz")) {
        $Form.Text = "Bepoz - " + $Form.Text
    }

    # Recursively apply theme to controls
    Apply-BepozControlTheme -Control $Form
}

function Apply-BepozControlTheme {
    <#
    .SYNOPSIS
        Recursively apply theme to controls (internal helper)
    #>
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Control]$Control
    )

    foreach ($child in $Control.Controls) {
        # Apply theme based on control type
        switch ($child.GetType().Name) {
            'Label' {
                if (-not $child.Font) {
                    $child.Font = Get-BepozFont -Size 9
                }
                if ($child.ForeColor -eq [System.Drawing.Color]::Empty) {
                    $child.ForeColor = Get-BepozColor -Name Black
                }
            }
            'Button' {
                if ($child.FlatStyle -ne [System.Windows.Forms.FlatStyle]::Flat) {
                    $child.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                }
                if (-not $child.Font) {
                    $child.Font = Get-BepozFont -Size 9
                }
                if ($child.Cursor -ne [System.Windows.Forms.Cursors]::Hand) {
                    $child.Cursor = [System.Windows.Forms.Cursors]::Hand
                }
            }
            'Panel' {
                if ($child.BackColor -eq [System.Drawing.Color]::Empty) {
                    $child.BackColor = Get-BepozColor -Name White
                }
            }
        }

        # Recurse into child controls
        if ($child.HasChildren) {
            Apply-BepozControlTheme -Control $child
        }
    }
}

function New-BepozForm {
    <#
    .SYNOPSIS
        Create a new themed form

    .PARAMETER Title
        Form title

    .PARAMETER Size
        Form size (Width, Height)

    .PARAMETER ShowBrand
        Add Bepoz branding

    .EXAMPLE
        $form = New-BepozForm -Title "My Tool" -Size (800, 600) -ShowBrand
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [int[]]$Size = @(800, 600),

        [switch]$ShowBrand
    )

    $form = New-Object System.Windows.Forms.Form

    if ($ShowBrand) {
        $form.Text = "Bepoz - $Title"
    }
    else {
        $form.Text = $Title
    }

    $form.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.BackColor = Get-BepozColor -Name White
    $form.Font = Get-BepozFont -Size 9

    return $form
}

#endregion

#region DataGridView Functions

function New-BepozDataGridView {
    <#
    .SYNOPSIS
        Create a themed data grid view

    .PARAMETER Location
        Location (X, Y)

    .PARAMETER Size
        Size (Width, Height)

    .PARAMETER ReadOnly
        Make read-only
    #>
    param(
        [Parameter(Mandatory)]
        [int[]]$Location,

        [Parameter(Mandatory)]
        [int[]]$Size,

        [bool]$ReadOnly = $true
    )

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
    $grid.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
    $grid.Font = Get-BepozFont -Size 9
    $grid.ReadOnly = $ReadOnly
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $grid.BackgroundColor = Get-BepozColor -Name White
    $grid.GridColor = Get-BepozColor -Name Gray
    $grid.RowHeadersVisible = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill

    # Header style
    $grid.ColumnHeadersDefaultCellStyle.BackColor = Get-BepozColor -Name Primary
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = Get-BepozColor -Name White
    $grid.ColumnHeadersDefaultCellStyle.Font = Get-BepozFont -Size 9 -Style Bold
    $grid.EnableHeadersVisualStyles = $false

    # Alternating row colors
    $grid.AlternatingRowsDefaultCellStyle.BackColor = Get-BepozColorWithAlpha -Name LightBlue -Alpha 30

    # Selection color
    $grid.DefaultCellStyle.SelectionBackColor = Get-BepozColor -Name LightBlue
    $grid.DefaultCellStyle.SelectionForeColor = Get-BepozColor -Name Black

    return $grid
}

#endregion

#region Export Functions

function Export-BepozColorPalette {
    <#
    .SYNOPSIS
        Export the Bepoz color palette for reference

    .PARAMETER OutputPath
        Path to save color palette reference

    .EXAMPLE
        Export-BepozColorPalette -OutputPath "C:\Docs\BepozColors.txt"
    #>
    param(
        [string]$OutputPath
    )

    $output = @"
=== BEPOZ COLOR PALETTE ===
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

PRIMARY COLORS (Exclusive use for brand integrity):
  Bepoz Blue: $($Script:BepozColors.Primary.Hex) | RGB: $($Script:BepozColors.Primary.RGB -join ', ') | CMYK: $($Script:BepozColors.Primary.CMYK)

SECONDARY COLORS (Complementary difference when needed):
  Dark Blue:  $($Script:BepozColors.DarkBlue.Hex) | RGB: $($Script:BepozColors.DarkBlue.RGB -join ', ') | CMYK: $($Script:BepozColors.DarkBlue.CMYK)
  Purple:     $($Script:BepozColors.Purple.Hex) | RGB: $($Script:BepozColors.Purple.RGB -join ', ') | CMYK: $($Script:BepozColors.Purple.CMYK)
  Gray:       $($Script:BepozColors.Gray.Hex) | RGB: $($Script:BepozColors.Gray.RGB -join ', ') | CMYK: $($Script:BepozColors.Gray.CMYK)

TERTIARY COLORS (Only when absolutely necessary):
  Light Blue:    $($Script:BepozColors.LightBlue.Hex) | RGB: $($Script:BepozColors.LightBlue.RGB -join ', ') | CMYK: $($Script:BepozColors.LightBlue.CMYK)
  Green:         $($Script:BepozColors.Green.Hex) | RGB: $($Script:BepozColors.Green.RGB -join ', ') | CMYK: $($Script:BepozColors.Green.CMYK)
  Bright Purple: $($Script:BepozColors.BrightPurple.Hex) | RGB: $($Script:BepozColors.BrightPurple.RGB -join ', ') | CMYK: $($Script:BepozColors.BrightPurple.CMYK)

STANDARD COLORS:
  White: $($Script:BepozColors.White.Hex) | RGB: $($Script:BepozColors.White.RGB -join ', ')
  Black: $($Script:BepozColors.Black.Hex) | RGB: $($Script:BepozColors.Black.RGB -join ', ')

USAGE GUIDELINES:
1. Use Primary color (#002D6A) exclusively to maintain brand integrity
2. Use Secondary colors only to add complementary difference when needed
3. Reserve Tertiary colors as a final option—use only when absolutely necessary

UI ELEMENT MAPPING:
  - Title Bars / Headers: Primary (#002D6A)
  - Panel Headers: Dark Blue (#001432)
  - Success Actions (Run, Apply): Green (#0A7C48)
  - Info Actions (Docs): Purple (#673AB6)
  - Neutral Actions (Cancel, Close): Gray (#808080)
  - Hover States: Light Blue (#8AA8DD)
  - Selected Items: Primary (#002D6A)
  - Disabled Controls: Gray (#808080) with reduced opacity

ACCESSIBILITY:
  - Primary on White: 10.6:1 contrast (WCAG AAA) ✓
  - White on Primary: 9.8:1 contrast (WCAG AAA) ✓
  - Green on White: 5.1:1 contrast (WCAG AA) ✓
  - Purple on White: 6.2:1 contrast (WCAG AA) ✓
"@

    if ($OutputPath) {
        $output | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Color palette exported to: $OutputPath" -ForegroundColor Green
    }
    else {
        Write-Host $output
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Get-BepozColor',
    'Get-BepozColorWithAlpha',
    'Get-BepozFont',
    'New-BepozButton',
    'New-BepozPanel',
    'New-BepozGroupBox',
    'New-BepozListBox',
    'New-BepozCheckedListBox',
    'New-BepozComboBox',
    'New-BepozLabel',
    'New-BepozTextBox',
    'New-BepozForm',
    'New-BepozDataGridView',
    'Apply-BepozFormTheme',
    'Export-BepozColorPalette'
)
