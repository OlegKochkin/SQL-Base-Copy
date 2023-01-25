# Папка для бэкапа на исходном сервере
$Global:TempFolderSrc = "C:\Windows\Temp\"
# Сетевой путь к папке для бэкапа на исходном сервере
$Global:TempFolderSrcUnc = '\C$\Windows\Temp\'
# Папка для бэкапа на целевом (этом) сервере
$Global:TempFolderDst = "C:\Windows\Temp\"

# При необходимости, установить альтернативные пути распожения файлов данных и журнала для целевого сервера
# $Global:DstMdfFile = "C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\$DstBase.mdf"
# $Global:DstLogFile = "F:\SQL_Log\"+$DstBase+"_log.ldf"
