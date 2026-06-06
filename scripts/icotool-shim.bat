@echo off
REM icotool shim - creates ICOs via Python/Pillow (no ImageMagick registry needed)
REM ECMAddAppIcon calls: icotool -c -o output.ico [-r hires.png] input.png...
set SCRIPT=%~dp0icotool-shim.py
python "%SCRIPT%" %*
