@echo off

if not exist out\ (
  mkdir out
)

set options=src\ -out:out\main.exe -debug -sanitize:address

if "%1" == "" (
  odin build %options%
) else if "%1" == "run" (
  odin run %options%
) else (
  echo invalid argument
  exit 1
)
