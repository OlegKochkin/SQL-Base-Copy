if ($ARGS.Length -le 0) {
	Write-Warning "Не указан список серверов в командной строке. Список серверов содержит адреса SQL серверов через пробел"
	exit
	}

Import-Module $PSScriptRoot\SQL-Base-Copy-Starter.psm1 -DisableNameChecking

$Global:SrcServer = $ARGS[0]
$Global:DstBase = ""
$LocalComp = Get-CimInstance -Class Win32_ComputerSystem
$DstServer = $LocalComp.Name+"."+$LocalComp.Domain

Add-Type -assembly System.Windows.Forms
$fm = New-Object System.Windows.Forms.Form
$fm.Text ="Копирование SQL базы с другого сервера на локальный ($DstServer)."
$fm.Width = 725
$fm.Height = 400
$fm.AutoSize = $True

$lSrcBases = New-Object System.Windows.Forms.Label
$lSrcBases.Text = "Исходный сервер"
$lSrcBases.AutoSize = 1
$lSrcBases.Location  = New-Object System.Drawing.Point(10,5)

$cbServers = New-Object System.Windows.Forms.ComboBox
$cbServers.Location  = New-Object System.Drawing.Point(10,25)
$cbServers.Width = 300
$cbServers.DropDownStyle = 2
$cbServers.DataSource = $ARGS

$cbServers.add_SelectedIndexChanged({
	$Global:SrcServer = $cbServers.SelectedItem
	Reload-Src-Bases
	Update-Status
	})

$lbSrcBases = New-Object System.Windows.Forms.ListBox
$lbSrcBases.Location = New-Object System.Drawing.Point(10,50)
$lbSrcBases.Size = New-Object System.Drawing.Size(300,($fm.Height-120))

function Update-Status {
	$eStatus.Text = "$($lbSrcBases.SelectedItem) ($Global:SrcServer) ---->>> $Global:DstBase (локальный, $DstServer)"
	if ($($lbSrcBases.SelectedItem) -and $Global:SrcServer -and $Global:DstBase) {
		$bCopy.Enabled = $True
		$bShortCut.Enabled = $True
		} else {
		$bCopy.Enabled = $False
		$bShortCut.Enabled = $False
		}
	$eNewBase.BackColor = $eNewBaseBkColor
	$Flag = $False
	if ($cbNewBase.Checked){
		foreach ($Item in $lbDstBases.Items){
			if ($Global:DstBase -eq $Item) {
				$Flag = $True
				$eNewBase.BackColor = "Red"
				}
			}
		}
	}

function Reload-Src-Bases {
	$lbSrcBases.Items.Clear()
	$Vis = $False
	sqlcmd -W -b -S $Global:SrcServer -Q "SELECT name FROM sys.databases ORDER BY name" | foreach {
		if ($_ -eq "") { $Vis = $False }
		if ($Vis) { if ($_ -NotIn ("master","tempdb","model","msdb")) { [void] $lbSrcBases.Items.Add($_) }}
		if ($_ -eq "----") { $Vis = $True }
		}
	}

$lbSrcBases.Add_SelectedIndexChanged({ Update-Status })
Reload-Src-Bases

$bCopy = New-Object System.Windows.Forms.Button
$bCopy.Location = New-Object System.Drawing.Point(315,180)
# $bCopy.Size = New-Object System.Drawing.Size(300,($fm.Height-120))
$bCopy.Enabled = $False
$bCopy.Text = "Копировать"
$bCopy.Add_Click({    
#	powershell .\SQL-Base-Copy.ps1 $Global:SrcServer $($lbSrcBases.SelectedItem) $Global:DstBase >> SQL-Base-Copy-Starter.log
#	Start-Process "powershell" -ArgumentList "$PSScriptRoot\SQL-Base-Copy.ps1","$Global:SrcServer","$($lbSrcBases.SelectedItem)","$Global:DstBase",";pause"
	Start-Process "$Global:BatFolder\SQL-Base-Copy.cmd" -ArgumentList "$Global:SrcServer","$($lbSrcBases.SelectedItem)","$Global:DstBase"
	$fm.Close()
  })

$bShortCut = New-Object System.Windows.Forms.Button
$bShortCut.Location = New-Object System.Drawing.Point(10,($fm.Height-55))
$bShortCut.Size = New-Object System.Drawing.Size(120,20)
$bShortCut.Enabled = $False
$bShortCut.Text = "Создать ярлык"
$bShortCut.Add_Click({    
	$WshShell = New-Object -comObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$Global:Jobs\From $Global:SrcServer $($lbSrcBases.SelectedItem) to $Global:DstBase.lnk")
	$Shortcut.TargetPath = "$Global:BatFolder\SQL-Base-Copy.cmd"
	$Shortcut.Arguments = "$Global:SrcServer $($lbSrcBases.SelectedItem) $Global:DstBase"
	$Shortcut.WorkingDirectory = "$Global:BatFolder"
	$Shortcut.Save()
  })

$lDstBases = New-Object System.Windows.Forms.Label
$lDstBases.Text = "Целевой (локальный) сервер ""$DstServer"""
$lDstBases.AutoSize = 1
$lDstBases.Location  = New-Object System.Drawing.Point(400,5)

$cbNewBase = New-Object System.Windows.Forms.CheckBox
$cbNewBase.Location = New-Object System.Drawing.Point(400,25)
$cbNewBase.Size = New-Object System.Drawing.Size(20,20)
$ttNebBase = New-Object System.Windows.Forms.ToolTip
$ttNebBase.SetToolTip($cbNewBase,"Создать новую базу`r`nПри смене с откл. на вкл., в поле целевой базы копируется имя исходной базы")
$cbNewBase.Add_CheckStateChanged({
	if ($cbNewBase.Checked) {
		$eNewBase.Enabled = $True
		$lbDstBases.Enabled = $False
		$eNewBase.Text = $lbSrcBases.SelectedItem
		$Global:DstBase = $eNewBase.Text
		Update-Status
		} else {
		$eNewBase.Enabled = $False
		$lbDstBases.Enabled = $True
		$Global:DstBase = $lbDstBases.SelectedItem
		Update-Status
		}
	})

$eNewBase = New-Object System.Windows.Forms.TextBox
$eNewBase.Location = New-Object System.Drawing.Point(420,25)
$eNewBase.Size = New-Object System.Drawing.Size(280,20)
$eNewBase.Text = "NEW_BASE"
$eNewBase.Enabled = $False
$eNewBaseBkColor = $eNewBase.BackColor
$eNewBase.Add_TextChanged({
	$Global:DstBase = $eNewBase.Text
	Update-Status
	})

$lbDstBases = New-Object System.Windows.Forms.ListBox
$lbDstBases.Location = New-Object System.Drawing.Point(400,50)
$lbDstBases.Size = New-Object System.Drawing.Size(300,($fm.Height-120))

$lbDstBases.Add_SelectedIndexChanged({
	$Global:DstBase = $lbDstBases.SelectedItem
	Update-Status
	})

$Vis = $False
sqlcmd -W -b -Q "SELECT name FROM sys.databases ORDER BY name" | foreach {
	if ($_ -eq "") { $Vis = $False }
	if ($Vis) { if ($_ -NotIn ("master","tempdb","model","msdb")) { [void] $lbDstBases.Items.Add($_) }}
	if ($_ -eq "----") { $Vis = $True }
	}

$eStatus = New-Object System.Windows.Forms.TextBox
$eStatus.Location = New-Object System.Drawing.Point(5,($fm.Height-25))
$eStatus.Size = New-Object System.Drawing.Size(($fm.Width-10),20)

$fm.Controls.AddRange(@($cbServers,$lSrcBases,$lDstBases,$lbSrcBases,$lbDstBases,$cbNewBase,$eNewBase,$bCopy,$eStatus,$bShortCut))

$fm.ShowDialog() | Out-Null
# Write-Host $fm.Width, $fm.Height