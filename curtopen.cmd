@echo off
rem Curt Viewer launcher — target of the .curt file association.
rem Generates a self-contained HTML copy of the offline viewer next to the
rem .curt file (falls back to %TEMP%) and opens it in the default browser.
rem All real work happens in curtopen.ps1; see README.md.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0curtopen.ps1" "%~1"
