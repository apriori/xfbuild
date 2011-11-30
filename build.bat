@echo off
setlocal EnableDelayedExpansion

set "MODULES="
for %%i in (*.d) do set MODULES=!MODULES! %%i

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

set "FLAGS=-g -w -wi -debug"
:: ~ set "FLAGS=-release -inline -O -noboundscheck"
set "VERSION=-version=MultiThreaded -version=Pipes"
:: ~ set "VERSION=-version=MultiThreaded -version=Pipes -unittest"
set "RUN="
:: ~ set "RUN=&& bin\xfbuild.exe"

dmd -ofbin\xfbuild.exe %FLAGS% %MODULES% %VERSION% -I.. -I..\WindowsAPI ..\WindowsAPI\win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib %RUN%
