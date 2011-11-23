@echo off
:: ~ echo wtf
setlocal EnableDelayedExpansion

set "MODULES="
for %%i in (*.d) do set MODULES=!MODULES! %%i

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

:: ~ dmd -ofadl.exe -g -w -wi %MODULES% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib -g -d -debug -J. -w -wi -unittest 

dmd -ofadl.exe -g -w -wi %MODULES% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib -g -d -debug -J. -w -wi -unittest && adl.exe test.d
