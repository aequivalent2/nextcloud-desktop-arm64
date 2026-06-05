@echo off
REM icotool shim - wraps ImageMagick so ECMAddAppIcon can create ICOs
REM ECMAddAppIcon calls: icotool --create -o output.ico [flags] input.png...
REM This shim translates to: magick input.png... output.ico
setlocal enabledelayedexpansion
set OUTPUT=
set INPUTS=
:parse
if "%~1"=="" goto done
if "%~1"=="--create" goto next
if "%~1"=="-c" goto next
if "%~1"=="-o" (set OUTPUT=%~2& shift& goto next)
if "%~1"=="--raw" goto next
if "%~1"=="-r" goto next
set INPUTS=!INPUTS! "%~1"
:next
shift
goto parse
:done
if "%OUTPUT%"=="" exit /b 1
magick !INPUTS! "%OUTPUT%"
