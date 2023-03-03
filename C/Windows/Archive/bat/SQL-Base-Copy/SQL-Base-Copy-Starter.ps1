# https://github.com/OlegKochkin/SQL-Base-Copy

if ($ARGS.Length -le 0) {
	Write-Warning "Не указан список серверов в командной строке. Список серверов содержит адреса SQL серверов через пробел"
	exit
	}

$Global:DstBasesDeleteEnable = $True
Import-Module $PSScriptRoot\SQL-Base-Copy-Starter.psm1 -DisableNameChecking

$Global:SrcServer = $ARGS[0]
$LocalComp = Get-CimInstance -Class Win32_ComputerSystem
$DstServer = $LocalComp.Name+"."+$LocalComp.Domain

Add-Type -assembly System.Windows.Forms
$fm = New-Object System.Windows.Forms.Form
$fm.Text ="Копмрование SQL базы с другого сервера на локальный ($DstServer)."
$fm.Width = 710
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
	$Global:DstBases = @()
	foreach ($DstBase in $lbDstBases.SelectedItems) {
		$Global:DstBases += $DstBase
		}
	if ($lbDstBases.SelectedItems){
		$bDelDst.Enabled = $True
		} else {
		$bDelDst.Enabled = $False
		}
	if ($cbNewBase.Checked){
		$Global:DstBases += $eNewBase.Text
		}
	$eStatus.Text = "$($lbSrcBases.SelectedItem) --> $Global:DstBases"
	if ($($lbSrcBases.SelectedItem) -and $Global:SrcServer -and $Global:DstBases) {
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
			if ($Item -eq $eNewBase.Text) {
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
$bCopy.Enabled = $False
$bCopy.Text = "Копировать"
$bCopy.Add_Click({
	Start-Process "$Global:BatFolder\SQL-Base-Copy.cmd" -ArgumentList "$Global:SrcServer","$($lbSrcBases.SelectedItem)","$Global:DstBases"
	$fm.Close()
  })

$bShortCut = New-Object System.Windows.Forms.Button
$bShortCut.Location = New-Object System.Drawing.Point(10,($fm.Height-55))
$bShortCut.Size = New-Object System.Drawing.Size(120,20)
$bShortCut.Enabled = $False
$bShortCut.Text = "Создать ярлык"
$bShortCut.Add_Click({
	$WshShell = New-Object -comObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$Global:Jobs\From $Global:SrcServer $($lbSrcBases.SelectedItem) to $Global:DstBases.lnk")
	$Shortcut.TargetPath = "$Global:BatFolder\SQL-Base-Copy.cmd"
	$Shortcut.Arguments = "$Global:SrcServer $($lbSrcBases.SelectedItem) $Global:DstBases"
	$Shortcut.WorkingDirectory = "$Global:BatFolder"
	$Shortcut.Save()
  })

$bDelDst = New-Object System.Windows.Forms.Button
$bDelDst.Location = New-Object System.Drawing.Point(($fm.Width-130),($fm.Height-55))
$bDelDst.Size = New-Object System.Drawing.Size(120,20)
$bDelDst.Enabled = $False
$bDelDst.Visible = $Global:DstBasesDeleteEnable
$bDelDst.Text = "Удалить базы..."
$bDelDst.Add_Click({
	$Bases = ""
	foreach ($DstBase in $lbDstBases.SelectedItems) {
		$Bases += $DstBase+"`r`n"
		}
	Add-Type -AssemblyName PresentationCore,PresentationFramework
	$Result = [System.Windows.MessageBox]::Show("Вы действительно желаете удалить, указанные ниже, SQL базы с локального сервера ""$DstServer""?`r`n`r`n$Bases","Удаление баз",4,48)
	if ($Result -eq "Yes"){
		foreach ($DstBase in $lbDstBases.SelectedItems) {
			sqlcmd -m1 -b -Q "USE [master];ALTER DATABASE [$DstBase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [$DstBase]"
			}
		Reload-Dst-Bases
		}
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
		$eNewBase.Text = $lbSrcBases.SelectedItem
		Update-Status
		} else {
		$eNewBase.Enabled = $False
		Update-Status
		}
	})

$eNewBase = New-Object System.Windows.Forms.TextBox
$eNewBase.Location = New-Object System.Drawing.Point(420,25)
$eNewBase.Size = New-Object System.Drawing.Size(280,20)
$eNewBase.Text = "NEW_BASE"
$eNewBase.Enabled = $False
$eNewBaseBkColor = $eNewBase.BackColor
$eNewBase.Add_TextChanged({Update-Status})

$lbDstBases = New-Object System.Windows.Forms.ListBox
$lbDstBases.Location = New-Object System.Drawing.Point(400,50)
$lbDstBases.Size = New-Object System.Drawing.Size(300,($fm.Height-120))
$lbDstBases.SelectionMode = "MultiExtended"
$ttDstBases = New-Object System.Windows.Forms.ToolTip
$ttDstBases.SetToolTip($lbDstBases,"Множественный выбор с зажатой клавишей CTRL")
$lbDstBases.Add_SelectedIndexChanged({Update-Status})

function Reload-Dst-Bases {
	$lbDstBases.Items.Clear()
	$Vis = $False
	sqlcmd -W -b -Q "SELECT name FROM sys.databases ORDER BY name" | foreach {
		if ($_ -eq "") { $Vis = $False }
		if ($Vis) { if ($_ -NotIn ("master","tempdb","model","msdb")) { [void] $lbDstBases.Items.Add($_) }}
		if ($_ -eq "----") { $Vis = $True }
		}
	}

Reload-Dst-Bases

$eStatus = New-Object System.Windows.Forms.TextBox
$eStatus.Location = New-Object System.Drawing.Point(5,($fm.Height-25))
$eStatus.Size = New-Object System.Drawing.Size(($fm.Width-10),20)

$fm.Controls.AddRange(@($cbServers,$lSrcBases,$lDstBases,$lbSrcBases,$lbDstBases,$cbNewBase,$eNewBase,$bCopy,$eStatus,$bShortCut,$bDelDst))
$fm.ShowDialog() | Out-Null
