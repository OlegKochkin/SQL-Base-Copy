@CD C:\Windows\Archive\bat\SQL-Base-Copy
@rem mkdir Logs 2> NUL
@rem powershell .\SQL-Base-Copy.ps1 %1 %2 %3 | wtee -a Logs\SQL-Base-Copy.log
@powershell .\SQL-Base-Copy.ps1 %1 %2 %3
@pause
