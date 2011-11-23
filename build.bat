@echo off
:: ~ echo wtf
rdmd -I.. -g -d -debug -J. -w -wi -unittest --main %*
:: ~ rdmd -g -d -debug -J. -w -wi %*
