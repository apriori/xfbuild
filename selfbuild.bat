@echo off
setlocal EnableDelayedExpansion

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

set "VERSION=-version=MultiThreaded"

xfbuild +obin\xfbuild.exe -g -w -wi -debug %VERSION% %WINVERSIONS% -version=MultiThreaded -I.. -I..\WindowsAPI\ -Idcollections-2.0c Main.d
