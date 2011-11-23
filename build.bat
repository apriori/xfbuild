@echo off
:: ~ echo wtf
rdmd -I.. -g -d -debug -J. -w -wi -unittest %*
:: ~ rdmd -g -d -debug -J. -w -wi %*
