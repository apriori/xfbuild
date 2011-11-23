@echo off
for %%i in (%*) do dmd %%i -L+..\dcollections.lib -I.. && testsets.exe
