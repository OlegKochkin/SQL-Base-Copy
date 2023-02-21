# https://github.com/OlegKochkin/SQL-Base-Copy

function Now {
	$(Get-Date -UFormat "%d.%m.%Y %H:%M:%S - ")
	}

function Del-Bak-File ($File) {
	if (Test-Path $File) {
		Write-Host "$(Now)Удаление файла бэкапа ""$File"""
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
	Write-Warning "Неправильные параметры командной строки."
	Write-Host "Запуск:"
	Write-Host "   SQL-Base-Copy.ps1 <Исходный SQL сервер> <Исходная SQL база> <Целевая SQL база на этом сервере> [Ещё целевые базы...]"
	Write-Host "Пример:"
	Write-Host "   SQL-Base-Copy.ps1 SRC.SERVER SRC_BASE DST_BASE_1 DST_BASE_2"
	exit(1)
	}

$DstBases = @()
$DstMdfFiles = @()
$DstLogFiles = @()

for ($i=2; $i -lt $ARGS.Length; $i++){
	$DstBases += $ARGS[$i]
# Файлы данных и журнала, создаваемые по умолчанию
	$DstMdfFiles += $(Get-SQL-Property "InstanceDefaultDataPath")+$ARGS[$i]+".mdf"
	$DstLogFiles += $(Get-SQL-Property "InstanceDefaultLogPath")+$ARGS[$i]+"_log.ldf"
	}

$SrcComp = $ARGS[0]
$SrcBase = $ARGS[1]
$LocalComp = Get-CimInstance -Class Win32_ComputerSystem
$DstComp = $LocalComp.Name+"."+$LocalComp.Domain+" (localhost)"

Import-Module $PSScriptRoot\SQL-Base-Copy.psm1 -DisableNameChecking

Write-Host "$(Now)Запущен скрипт $PSCommandPath для копирования SQL базы.`n`r"
Write-Host "Исходный сервер: $SrcComp"
Write-Host "Исходная база:   $SrcBase"
Write-Host "Целевой сервер:  $DstComp`r`n"
for ($i=0; $i -lt $DstBases.Length; $i++){
	Write-Host "Целевая база:    $($DstBases[$i])"
	Write-Host "Будет восстановлена в файлы:"
	Write-Host "	$($DstMdfFiles[$i])"
	Write-Host "	$($DstLogFiles[$i])"
	}

Write-Host -NoNewLine -ForegroundColor Yellow "`n`rПродолжить? (y/N)"
$Key = Read-Host
if ($Key.ToUpper() -ne "Y"){
	Write-Host "`n`r$(Now)Отказ от выполнения скрипта."
	exit
	}
Write-Host "`n`r"

$SuffixBak = "-script-backup-$([guid]::NewGuid().ToString('N').Remove(8)).bak"
$TempFile = $TempFolderSrc+$SrcBase+$SuffixBak
$SrcTemp = '\\'+$SrcComp+$TempFolderSrcUnc+$SrcBase+$SuffixBak
$DstTemp = $TempFolderDst+$SrcBase+$SuffixBak

Write-Host "$(Now)Бэкап SQL базы ""$SrcBase"" на сервере ""$SrcComp"" в ""$TempFile""..."
sqlcmd -m1 -b -S $SrcComp -Q "BACKUP DATABASE [$SrcBase] TO DISK = N'$TempFile' WITH NOFORMAT, INIT, NAME = N'Full Backup $SrcBase', NOSKIP, REWIND, NOUNLOAD, STATS = 10"
if (-Not $?) {
	Write-Host "$(Now)Создание бэкапа было неудачным. Выполнение скрипта прервано."
	Del-Bak-File $TempFile
	exit
	}

Write-Host "$(Now)Перемещение файла бэкапа из ""$SrcTemp"" в ""$DstTemp""..."
if (Test-Path $SrcTemp) {
	Move-Item $SrcTemp $DstTemp -Force
	} else {
	Write-Warning "$(Now)Файл бэкапа ""$SrcTemp"" на сервере ""$DstComp"" не обнаружен."
	Write-Host "$(Now)Возможно, бэкап был неудачен. Выполнение скрипта прервано."
	exit
	}

# Получение имён файлов данных и журнала из архива
$SrcMdfFile = Get-Src-SQL-File $DstTemp ".mdf"
$SrcLogFile = Get-Src-SQL-File $DstTemp ".ldf"

if (Test-Path $DstTemp) {
	for ($i=0; $i -lt $DstBases.Length; $i++){
		sqlcmd -m1 -b -Q "IF DB_ID('$($DstBases[$i])') IS NULL CREATE DATABASE [$($DstBases[$i])]"
		if (-Not $?) {
			Write-Host "$(Now)Создание SQL базы было неудачным."
			}
		Write-Host "$(Now)Восстановление SQL базы ""$($DstBases[$i])"" на сервере ""$DstComp"" из ""$DstTemp""..."
		sqlcmd -m1 -b -Q "ALTER DATABASE [$($DstBases[$i])] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;RESTORE DATABASE [$($DstBases[$i])] FROM  DISK = N'$DstTemp' WITH  FILE = 1,  MOVE N'$SrcMdfFile' TO N'$($DstMdfFiles[$i])',  MOVE N'$SrcLogFile' TO N'$($DstLogFiles[$i])',  NOUNLOAD,  REPLACE,  STATS = 10;ALTER DATABASE [$($DstBases[$i])] SET MULTI_USER"
		if (-Not $?) {
			Write-Host "$(Now)Восстановление из бэкапа было неудачным."
			}
		}
	}
Del-Bak-File $DstTemp
Write-Host "$(Now)Скрипт завершён."
