@echo off
setlocal
rem Curt Viewer — register the .curt file association.
rem
rem WHAT THIS DOES, plainly:
rem   - Writes four values under HKEY_CURRENT_USER\Software\Classes:
rem       .curt -> curtfile                        (extension points at a class)
rem       curtfile -> "Curt conversation"          (human-readable type name)
rem       curtfile\shell\open -> "Open with Curt Viewer"   (verb label)
rem       curtfile\shell\open\command -> "<this folder>\<handler>" "%1"
rem     where <handler> is CurtViewer.exe (the native launcher — no console
rem     flash when you double-click a .curt file) when it exists or can be
rem     built, and curtopen.cmd otherwise.
rem   - HKCU only: current user, no admin rights needed, nothing machine-wide.
rem   - It does NOT copy files anywhere. Keep this folder where it is; the
rem     association points into it.
rem   - Undo with uninstall.cmd (which deletes those same keys).

set "PKGDIR=%~dp0"
if not exist "%PKGDIR%curtopen.ps1" (
	echo [curt-openwith] curtopen.ps1 not found next to install.cmd - run this
	echo from the extracted package folder, not from inside a zip preview.
	exit /b 1
)

rem Prefer the native launcher; build it on the spot if the in-box compiler
rem is available, otherwise fall back to the .cmd wrapper (identical
rem behavior, just shows a console window).
set "HANDLER="
if exist "%PKGDIR%CurtViewer.exe" set "HANDLER=%PKGDIR%CurtViewer.exe"
if not defined HANDLER call :build_exe
if not defined HANDLER set "HANDLER=%PKGDIR%curtopen.cmd"

echo Curt Viewer: registering the .curt file association for the current user...
echo   open command: "%HANDLER%" "%%1"
if "%HANDLER%"=="%PKGDIR%curtopen.cmd" (
	echo   ^(CurtViewer.exe not available - using the curtopen.cmd wrapper. It works
	echo    the same; a console window flashes briefly on each open.^)
)

reg add "HKCU\Software\Classes\.curt" /ve /t REG_SZ /d "curtfile" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile" /ve /t REG_SZ /d "Curt conversation" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile\shell\open" /ve /t REG_SZ /d "Open with Curt Viewer" /f >nul || goto :fail
reg add "HKCU\Software\Classes\curtfile\shell\open\command" /ve /t REG_SZ /d "\"%HANDLER%\" \"%%1\"" /f >nul || goto :fail

echo Done. Double-clicking a .curt file now opens it in the Curt Viewer.
echo Note: already-open Explorer windows may need a refresh ^(F5^) to pick it up.
exit /b 0

:build_exe
rem Compiles CurtViewer.exe from src-windows\CurtViewer.cs with the C#
rem compiler Windows ships in the box — no SDK, no downloads.
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
	echo   no in-box C# compiler found - skipping the CurtViewer.exe build.
	exit /b 1
)
if not exist "%PKGDIR%src-windows\CurtViewer.cs" exit /b 1
echo   CurtViewer.exe not found - building it with the in-box compiler...
"%CSC%" /nologo /target:winexe /out:"%PKGDIR%CurtViewer.exe" /r:System.dll /r:System.Windows.Forms.dll "%PKGDIR%src-windows\CurtViewer.cs"
if errorlevel 1 (
	echo   CurtViewer.exe build failed - falling back to curtopen.cmd.
	exit /b 1
)
echo   built %PKGDIR%CurtViewer.exe
set "HANDLER=%PKGDIR%CurtViewer.exe"
exit /b 0

:fail
echo Registration FAILED - the registry could not be written. Nothing was changed
echo beyond the keys above that did succeed; run uninstall.cmd to clean those up.
exit /b 1
