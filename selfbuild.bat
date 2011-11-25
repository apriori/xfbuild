@echo off
del /q xfbuild.exe
xfbuild +obin\xfbuild.exe -debug -version=MultiThreaded -I.. -I..\WindowsAPI\ -Idcollections-2.0c Main.d
