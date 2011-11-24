@echo off
del /q xfbuild.exe
xfbuild +oxfbuild.exe -debug -version=MultiThreaded -I.. -I..\WindowsAPI\ -Idcollections-2.0c Main.d
copy xfbuild.exe D:\path\xfbuild.exe
