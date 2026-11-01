@echo off
setlocal
rem Curt Viewer — remove the .curt file association.
rem
rem WHAT THIS DOES, plainly:
rem   - Deletes HKCU\Software\Classes\.curt and HKCU\Software\Classes\curtfile
rem     (the same keys install.cmd wrote), current user only, no admin.
rem   - Your .curt files are not touched; they just lose their default
rem     "open with" app. If some other app owned .curt before install.cmd ran,
rem     that association is not restored — re-associate from Explorer if needed.

echo Curt Viewer: removing the .curt file association for the current user...

reg delete "HKCU\Software\Classes\.curt" /f >nul 2>&1 || echo   (no .curt extension key — already gone)
reg delete "HKCU\Software\Classes\curtfile" /f >nul 2>&1 || echo   (no curtfile class key — already gone)

echo Done. Double-clicking a .curt file will no longer open the Curt Viewer.
exit /b 0
