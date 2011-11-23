@echo off
:: ~ echo wtf
setlocal EnableDelayedExpansion

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

rdmd -I.. -I..\WindowsAPI %WINVERSIONS% -g -d -debug -J. -w -wi -unittest --main %*
:: ~ rdmd -g -d -debug -J. -w -wi %*
