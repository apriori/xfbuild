@echo off
setlocal EnableDelayedExpansion

set "MODULES="
for %%i in (*.d) do set MODULES=!MODULES! %%i

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

:: ~ set "VERSION="
set "VERSION=-version=MultiThreaded"

:: ~ dmd -ofxfbuild.exe -g -w -wi %MODULES% %VERSION% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib -g -d -debug -J. -w -wi -unittest && xfbuild.exe +otest\test.exe +v test\test.d

dmd -ofD:\path\xfbuild.exe -g -w -wi %MODULES% %VERSION% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib -g -d -debug -J. -w -wi -unittest
