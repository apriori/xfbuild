@echo off
setlocal EnableDelayedExpansion

set "MODULES="
for %%i in (*.d) do set MODULES=!MODULES! %%i

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

set "VERSION=-version=MultiThreaded"

dmd -ofbin\xfbuild.exe -g -w -wi -debug -J. -unittest %MODULES% %VERSION% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib && bin\xfbuild.exe
