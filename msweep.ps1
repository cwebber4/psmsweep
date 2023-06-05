#Copyright 2019-2023 Chris Webber

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#powershell -executionpolicy bypass -File .\msweep.ps1

#bugs:
#clearOpenField will clear fields that are marked as a mine but aren't actually a mine.
#field marked as a mine should not be clearable (enabled, clickable).
#when revealing mines on game over, correctly marked mines should still show as M. incorrect ones should be marked.

$numRows = 16
$numCols = 16
$numMines = 40

$buttonWidth = 20
$buttonHeight = 20

$mine = "X"

$directions = @(
  @(-1, 0), #N
  @(-1, 1), #NE
  @(0, 1),  #E
  @(1, 1),  #SE
  @(1, 0),  #S
  @(1, -1), #SW
  @(0, -1), #W
  @(-1, -1) #NW
)

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.AutoSize = $True
$mainForm.FormBorderStyle = "FixedSingle"
$mainForm.Height = $numRows * $buttonHeight
$mainForm.Width = $numCols * $buttonWidth

$rows = New-Object System.Windows.Forms.Control[][] $numRows

function init
{
  initForm
  initGame

  #debug

  $mainForm.showDialog()
}

function initForm
{
  $mainForm.Text = "MSweep"
  $mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $mainForm.Location = New-Object System.Drawing.Point(1400, 150)

  $menuStrip = New-Object System.Windows.Forms.MenuStrip
  $menuStrip.Name = "MenuStrip"

  $fileMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&File")

  $newMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&New")

  #bitwise compare Alt and N
  $newMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Alt -bor [System.Windows.Forms.Keys]::N
  $newMenuItem.add_Click(
    {
      initGame
    }
  );

  $closeMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("&Close")

  #bitwise compare Alt and X
  $closeMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Alt -bor [System.Windows.Forms.Keys]::X
  $closeMenuItem.add_Click(
    {
      $mainForm.Close()
    }
  );

  $fileMenuItem.DropDownItems.Add($newMenuItem)
  $fileMenuItem.DropDownItems.Add($closeMenuItem)

  $menuStrip.Items.Add($fileMenuItem)

  $mainForm.Controls.Add($menuStrip)

  #create buttons
  $heightOffset = $menuStrip.Height
  for ($rowCount = 0; $rowCount -lt $numRows; ++$rowCount)
  {
    $row = New-Object System.Windows.Forms.Button[] $numCols
    for ($colCount = 0; $colCount -lt $numCols; ++$colCount)
    {
      $buttonNumber = ($rowCount * $numCols) + $colCount

      $button = New-Object System.Windows.Forms.Button
      $button.Width = $buttonWidth
      $button.Height = $buttonHeight
      $button.Left = $colCount * $button.Width
      $button.Top = ($rowCount * $button.Height) + $heightOffset
      $button.Name = $buttonNumber
      $button.Tag = "0"
      $button.TabStop = $false;

      $button.add_click(
        {
          clearPlot $this.Name
        }
      )

      $button.add_MouseUp(
        {
          if ($_.Button -eq [Windows.Forms.MouseButtons]::Right)
          {
            markPlot $this.Name
          }
        }
      )

      $row[$colCount] = $button
      $mainForm.Controls.Add($button)
    }

    $rows[$rowCount] = $row
  }
}

function initGame
{
  #reset buttons
  for ($rowCount = 0; $rowCount -lt $numRows; ++$rowCount)
  {
    for ($colCount = 0; $colCount -lt $numCols; ++$colCount)
    {
      $button = $rows[$rowCount][$colCount]
      $button.Enabled = $true
      $button.Tag = "0"
      $button.Text = ""
      $button.FlatStyle = 'Standard'
      $button.BackColor = [System.Drawing.Color]::WhiteSmoke

      # $button.Font = New-Object System.Drawing.Font($button.Font.Name, $button.Font.Size, [System.Drawing.Font]::Bold)
      $button.Font = New-Object System.Drawing.Font($button.Font.Name, $button.Font.Size, [System.Drawing.FontStyle]::Bold)
      # $button.BackColor = [System.Drawing.Color]::White
    }
  }

  placeMines
}

function placeMines
{
  $rand = New-Object System.Random([Datetime]::Now.Millisecond)

  for ($mineCount = 0; $mineCount -lt $numMines; ++$mineCount)
  {
    $button = $null

    #find an empty field.
    do
    {
      $mineRow = $rand.Next(0, $numRows)
      $mineCol = $rand.Next(0, $numCols)
      $button = $rows[$mineRow][$mineCol]
    } while ($button.Tag -eq $mine)

    #set mine
    $button.Tag = $mine

    increaseMarkers $mineRow $mineCol

    #debug

    #$button.Text = $button.Tag
  }
}

function increaseMarkers($mineRow, $mineCol)
{
  foreach ($direction in $directions)
  {
    $nextRow = $mineRow + $direction[0]
    $nextCol = $mineCol + $direction[1]

    if ($nextRow -ge 0 -and $nextRow -lt $numRows -and $nextCol -ge 0 -and $nextCol -lt $numCols)
    {
      $button = $rows[$nextRow][$nextCol]
      if ($button.Tag -ne $mine)
      {
        $button.Tag = [string]([int]$button.Tag + 1)

        #debug

        #$button.Text = $button.Tag
      }
    }
  }
}

function clearPlot($buttonNum)
{
  $buttonRow = [Math]::Floor($buttonNum / $numRows)
  $buttonCol = $buttonNum % $numCols
  $button = $rows[$buttonRow][$buttonCol]

  if ($button.Text -ne "M")
  {
    if ($button.Tag -eq $mine)
    {
      $button.BackColor = [System.Drawing.Color]::Red
      revealMines
    }
    elseif ($button.Tag -eq "0")
    {
      $button.FlatStyle = 'Flat'
      $button.BackColor = [System.Drawing.Color]::LightGray
      $button.Text = $button.Tag
      $button.Enabled = $false
      # $button.Focus()
      clearOpenField $buttonNum
    }
    else
    {
      $button.FlatStyle = 'Flat'
      $button.BackColor = [System.Drawing.Color]::LightGray
      $button.Text = $button.Tag
      $button.Enabled = $false
    }
  }
}

function revealMines
{
  for ($rowCount = 0; $rowCount -lt $numRows; ++$rowCount)
  {
    for ($colCount = 0; $colCount -lt $numCols; ++$colCount)
    {
      $button = $rows[$rowCount][$colCount]
      $button.Enabled = $false
      # $button.BackColor = [System.Drawing.Color]::LightGray
      
      if ($button.Tag -eq $mine)
      {
        $button.Text = $button.Tag
      }
   }
  }
}

function clearOpenField($buttonNum)
{
  $buttonRow = [Math]::Floor($buttonNum / $numRows)
  $buttonCol = $buttonNum % $numCols
  $currentButton = $rows[$buttonRow][$buttonCol]

  if ($currentButton.Tag -eq "0")
  {
    foreach ($direction in $directions)
    {
      $nextRow = $buttonRow + $direction[0]
      $nextCol = $buttonCol + $direction[1]

      if ($nextRow -ge 0 -and $nextRow -lt $numRows -and $nextCol -ge 0 -and $nextCol -lt $numCols)
      {
        $nextButton = $rows[$nextRow][$nextCol]
        # if ($nextButton.Enabled -eq $true -and $nextButton.Tag -eq "0")
        if ($nextButton.Enabled -eq $true)
        {
          clearPlot $nextButton.Name
        }
      }
    }
  }
}

function markPlot($buttonNum)
{
  $buttonRow = [Math]::Floor($buttonNum / $numRows)
  $buttonCol = $buttonNum % $numCols
  $button = $rows[$buttonRow][$buttonCol]

  if ($button.Enabled)
  {
    if ($button.Text -eq "")
    {
      $button.Text = "M"
    }
    elseif ($button.Text -eq "M")
    {
      $button.Text = "?"
    }
    else
    {
      $button.Text = ""
    }
  }
}

function debug
{
  for ($rowCount = 0; $rowCount -lt $numRows; ++$rowCount)
  {
    for ($colCount = 0; $colCount -lt $numCols; ++$colCount)
    {
      $button = $rows[$rowCount][$colCount]
      $button.Text = $button.Tag
    }
  }
}

init