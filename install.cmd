@echo off
setlocal
rem Curt Viewer — register the .curt file association.
rem
rem WHAT THIS DOES, plainly:
rem   - Writes four values under HKEY_CURRENT_USER\Software\Classes:
rem       .curt -> curtfile                        (extension points at a class)
rem       curtfile -> "Curt conversation"          (human-readable type name)
rem       curtfile\shell\open -> "Open with Curt Viewer"   (verb label)
rem       curtfile\shell\open\command -> "<this folder>\curtopen.cmd" "%1"
rem   - HKCU only: current user, no admin rights needed, nothing machine-wide.
rem   - It does NOT copy files anywhere. Keep this folder where it is; the
rem     association points into it.
rem   - Undo with uninstall.cmd (which deletes those same keys).

set "PKGDIR=%~dp0"
if not exist "%PKGDIR%curtopen.cmd" (
	echo [curt-openwith] curtopen.cmd not found next to install.cmd - run this
	echo from the extracted package folder, not from inside a zip preview.
	exit /b 1
)

echo Curt Viewer: registering the .curt file association for the current user...
echo   open command: "%PKGDIR%curtopen.cmd" "%%1"

reg add "HKCU\Software\Classes\.curt" /ve /t REG_SZ /d "curtfile" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile" /ve /t REG_SZ /d "Curt conversation" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile\shell\open" /ve /t REG_SZ /d "Open with Curt Viewer" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile\shell\open\command" /ve /t REG_SZ /d "\"%PKGDIR%curtopen.cmd\" \"%%1\"" /f >nul || goto :fail

echo Done. Double-clicking a .curt file now opens it in the Curt Viewer.
echo Note: already-open Explorer windows may need a refresh ^(F5^) to pick it up.
exit /b 0

:fail
echo Registration FAILED - the registry could not be written. Nothing was changed
echo beyond the keys above that did succeed; run uninstall.cmd to clean those up.
exit /b 1
