# https://github.com/OlegKochkin/SQL-Base-Copy

function Now {
	$(Get-Date -UFormat "%d.%m.%Y %H:%M:%S - ")
	}

function Del-Bak-File ($File) {
	if (Test-Path $File) {
		Write-Host "$(Now)�������� ����� ������ ""$File"""
		Remove-Item $File -Force
		}
	}

function Get-SQL-Property ($Prop) {
	$Vis = $False
	sqlcmd -W -b -Q "SELECT SERVERPROPERTY ('$Prop') AS Value" | foreach {
		if ($_ -eq "") { $Vis = $False }
		if ($Vis) {$_}
		if ($_ -eq "-----") { $Vis = $True }
		}
	}

function Get-Src-SQL-File ($BakFile,$Mask) {
	$NameAll = sqlcmd -b -W -Q "RESTORE FILELISTONLY FROM DISK = N'$BakFile'" | Select-String $Mask
	if ($?) {
		($NameAll -split " ")[0]
		} else { $False }
	}

if ($ARGS.Length -lt 3){
	Write-Warning "������������ ��������� ��������� ������."
	Write-Host "������:"
	Write-Host "   SQL-Base-Copy.ps1 <�������� SQL ������> <�������� SQL ����> <������� SQL ���� �� ���� �������> [��� ������� ����...]"
	Write-Host "������:"
	Write-Host "   SQL-Base-Copy.ps1 SRC.SERVER SRC_BASE DST_BASE_1 DST_BASE_2"
	exit(1)
	}

$DstBases = @()
$DstMdfFiles = @()
$DstLogFiles = @()

for ($i=2; $i -lt $ARGS.Length; $i++){
	$DstBases += $ARGS[$i]
# ����� ������ � �������, ����������� �� ���������
	$DstMdfFiles += $(Get-SQL-Property "InstanceDefaultDataPath")+$ARGS[$i]+".mdf"
	$DstLogFiles += $(Get-SQL-Property "InstanceDefaultLogPath")+$ARGS[$i]+"_log.ldf"
	}

$SrcComp = $ARGS[0]
$SrcBase = $ARGS[1]
$LocalComp = Get-CimInstance -Class Win32_ComputerSystem
$DstComp = $LocalComp.Name+"."+$LocalComp.Domain+" (localhost)"

Import-Module $PSScriptRoot\SQL-Base-Copy.psm1 -DisableNameChecking

Write-Host "$(Now)������� ������ $PSCommandPath ��� ����������� SQL ����.`n`r"
Write-Host "�������� ������: $SrcComp"
Write-Host "�������� ����:   $SrcBase"
Write-Host "������� ������:  $DstComp`r`n"
for ($i=0; $i -lt $DstBases.Length; $i++){
	Write-Host "������� ����:    $($DstBases[$i])"
	Write-Host "����� ������������� � �����:"
	Write-Host "	$($DstMdfFiles[$i])"
	Write-Host "	$($DstLogFiles[$i])"
	}

Write-Host -NoNewLine -ForegroundColor Yellow "`n`r����������? (y/N)"
$Key = Read-Host
if ($Key.ToUpper() -ne "Y"){
	Write-Host "`n`r$(Now)����� �� ���������� �������."
	exit
	}
Write-Host "`n`r"

$SuffixBak = "-script-backup-$([guid]::NewGuid().ToString('N').Remove(8)).bak"
$TempFile = $TempFolderSrc+$SrcBase+$SuffixBak
$SrcTemp = '\\'+$SrcComp+$TempFolderSrcUnc+$SrcBase+$SuffixBak
$DstTemp = $TempFolderDst+$SrcBase+$SuffixBak

Write-Host "$(Now)����� SQL ���� ""$SrcBase"" �� ������� ""$SrcComp""..."
sqlcmd -m1 -b -S $SrcComp -Q "BACKUP DATABASE [$SrcBase] TO DISK = N'$TempFile' WITH NOFORMAT, INIT, NAME = N'Full Backup $SrcBase', NOSKIP, REWIND, NOUNLOAD, STATS = 10"
if (-Not $?) {
	Write-Host "$(Now)�������� ������ ���� ���������. ���������� ������� ��������."
	Del-Bak-File $TempFile
	exit
	}

Write-Host "$(Now)����������� ����� ������..."
if (Test-Path $SrcTemp) {
	Move-Item $SrcTemp $DstTemp -Force
	} else {
	Write-Warning "$(Now)���� ������ ""$SrcTemp"" �� ������� ""$DstComp"" �� ���������."
	Write-Host "$(Now)��������, ����� ��� ��������. ���������� ������� ��������."
	exit
	}

# ��������� ��� ������ ������ � ������� �� ������
$SrcMdfFile = Get-Src-SQL-File $DstTemp ".mdf"
$SrcLogFile = Get-Src-SQL-File $DstTemp ".ldf"

if (Test-Path $DstTemp) {
	for ($i=0; $i -lt $DstBases.Length; $i++){
		sqlcmd -m1 -b -Q "IF DB_ID('$($DstBases[$i])') IS NULL CREATE DATABASE [$($DstBases[$i])]"
		if (-Not $?) {
			Write-Host "$(Now)�������� SQL ���� ���� ���������."
			}
		Write-Host "$(Now)�������������� SQL ���� ""$($DstBases[$i])""..."
		sqlcmd -m1 -b -Q "ALTER DATABASE [$($DstBases[$i])] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;RESTORE DATABASE [$($DstBases[$i])] FROM  DISK = N'$DstTemp' WITH  FILE = 1,  MOVE N'$SrcMdfFile' TO N'$($DstMdfFiles[$i])',  MOVE N'$SrcLogFile' TO N'$($DstLogFiles[$i])',  NOUNLOAD,  REPLACE,  STATS = 10;ALTER DATABASE [$($DstBases[$i])] SET MULTI_USER"
		if (-Not $?) {
			Write-Host "$(Now)�������������� �� ������ ���� ���������."
			}
		}
	}
Del-Bak-File $DstTemp
Write-Host "$(Now)������ ��������."
