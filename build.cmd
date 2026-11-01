@echo off
setlocal
rem CurtViewer.exe build — uses the .NET Framework C# compiler that ships
rem in every Windows install (C:\Windows\Microsoft.NET\...\csc.exe), so no
rem SDK, no Visual Studio, no downloads. The exe this produces is the same
rem one shipped in the release zip: reproducible from this script alone.

set "SRC=%~dp0src-windows\CurtViewer.cs"
set "OUT=%~dp0CurtViewer.exe"

if not exist "%SRC%" (
	echo [build] source not found: %SRC%
	exit /b 1
)

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
	echo [build] no in-box csc.exe found under %WINDIR%\Microsoft.NET - this
	echo script needs only the .NET Framework compiler Windows ships with.
	exit /b 1
)

"%CSC%" /nologo /target:winexe /out:"%OUT%" /r:System.dll /r:System.Windows.Forms.dll "%SRC%"
if errorlevel 1 (
	echo [build] compile failed
	exit /b 1
)
echo [build] wrote %OUT%
exit /b 0
