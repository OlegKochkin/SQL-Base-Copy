# SQL-Base-Copy
Копирование MS SQL баз с внешнего сервера на локальный посредством backup/restore

"C:\Windows\Archive\bat\SQL-Base-Copy.cmd" - "Батник" для запуска копирования SQL баз

Параметры запуска : SQL-Base-Copy.cmd <Адрес исходного сервера> <Исходная база> <Целевая база на этом сервере> [Ещё целевые базы...]

Скрипты PowerShell находятся в папке "C:\Windows\Archive\bat\SQL-Base-Copy":

"SQL-Base-Copy.ps1" - основной скрипт

![SQL-Base-Copy.ps1](.pics/SQL-Base-Copy.png)

Параметры запуска : SQL-Base-Copy.ps1 <Адрес исходного сервера> <Исходная база> <Целевая база на этом сервере>  [Ещё целевые базы...]

"SQL-Base-Copy.psm1" - переменные для "SQL-Base-Copy.ps1":
Папка для бэкапа на исходном сервере: "$Global:TempFolderSrc" ("C:\Windows\Temp\")
Сетевой путь к папке для бэкапа на исходном сервере: "$Global:TempFolderSrcUnc" ('\C$\Windows\Temp\')
Папка для бэкапа на целевом (этом) сервере "$Global:TempFolderDst" ("C:\Windows\Temp\")
Пути для создания файлов данных и журнала SQL баз при восстановлении из бэкапа. Эти опции необязательны, по умолчанию используются пути, установленные в свойствах сервера для новых баз.

"SQL-Base-Copy-Starter.ps1" - GUI скрипт для интерактивного выбора исходных серверов, исходных и целевых баз, и запуска "SQL-Base-Copy.cmd"

![SQL-Base-Copy-Starter.ps1](.pics/s.png)

- В качестве параметров командной строки передаются адреса серверов, с которых необходимо копировать SQL базы
- В качестве целевых баз используются базы, выбранные из списка существующих локальных баз и(или) новая база
- Если при вводе имени новой целевой базы, имя совпадает с уже существующей, поле ввода подсвечивается красным цветом
- Кнопки "Копировать" и "Создать ярлык" доступны, когда адрес исходного сервера и имена исходной и целевой баз непустые
- При нажатии кнопки "Копировать", стартёр завершается и запускается "SQL-Base-Copy.cmd"
- При нажатии кнопки "Создать ярлык", создаётся ярлык для запуска "SQL-Base-Copy.cmd" с выбранными параметрами

Ярлык создаётся с отключеным флагом "Запускать от имени Администратора". Если не будет хватать прав, включить в свойствах ярлыка. в "Дополнительно".
	
"SQL-Base-Copy-Starter.psm1" - переменные для "SQL-Base-Copy-Starter.ps1"
Папка расположения командного файла "SQL-Base-Copy.cmd": "$Global:BatFolder" ("C:\Windows\Archive\bat")
Папка "Задания" для сохранения ярлыков: "$Global:Jobs" ("C:\Users\$ENV:UserName\Desktop\Задания")

Параметры ярлыка для запуска "SQL-Base-Copy-Starter.psm1":
Объект: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -File C:\Windows\Archive\bat\SQL-Base-Copy\SQL-Base-Copy-Starter.ps1 Server1 Server2 Server3
Рабочая папка: C:\Windows\Archive\bat\SQL-Base-Copy
Окно: Свёрнутое в значок

Условия работы скрипта:
- На исходных серверах должен быть открыт порт TCP/1433
- Пользователь должен иметь права работать с исходными и целевым SQL серверами
- Пользователь должен иметь права на чтение и удаление в папках "$Global:TempFolderSrcUnc" на исходных серверах и в папке "$Global:TempFolderDst" на целевом сервере
