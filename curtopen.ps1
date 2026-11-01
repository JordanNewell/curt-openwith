# Curt Viewer launcher (curt-openwith).
# Given a .curt file, builds a self-contained HTML copy of the offline viewer
# next to it with the file's JSON body injected as window.__OPENED_FILE, then
# opens that HTML in the default browser. See README.md for how it works.
# The viewer HTML embeds a plain-text copy of the conversation; it renders in
# the browser and touches no network. Delete the view-*.html file to erase it.

#Requires -Version 5.1
param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$CurtFile,
	# Internal: skip the browser launch (used by the package's own tests).
	[switch]$NoLaunch,
	# Internal: skip the friendly error dialog, writing the error to stderr
	# instead (used by the package's own tests — a modal dialog would block
	# an automated run).
	[switch]$NoDialog
)

$ErrorActionPreference = "Stop"

function Get-LongPath([string]$Path) {
	# Windows PowerShell's .NET caps paths at 260 chars; the \\?\ prefix lifts
	# the cap. UNC paths get the \\?\UNC\ form.
	if ($Path.Length -lt 248 -or $Path.StartsWith("\\?\")) { return $Path }
	if ($Path.StartsWith("\\")) {
		return "\\?\UNC\" + $Path.Substring(2)
	}
	return "\\?\" + $Path
}

try {
	if (-not [IO.File]::Exists((Get-LongPath $CurtFile))) {
		throw "File not found: $CurtFile"
	}

	# Read bytes and decode BOM-aware, mirroring what the viewer's own
	# drop handler would do (UTF-16LE/BE, then assume UTF-8).
	$bytes = [IO.File]::ReadAllBytes((Get-LongPath $CurtFile))
	if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
		$text = [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
	} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
		$text = [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
	} else {
		$text = [Text.Encoding]::UTF8.GetString($bytes)
	}

	$viewerPath = Join-Path $PSScriptRoot "viewer\index.html"
	if (-not [IO.File]::Exists($viewerPath)) {
		throw "The viewer template is missing: $viewerPath (did the package get moved without its viewer folder?)"
	}
	$html = [IO.File]::ReadAllText($viewerPath)

	# Inject the file as window.__OPENED_FILE = {name, text}. ConvertTo-Json
	# produces the string literal; replacing every '<' with \u003c afterwards
	# makes any smuggled "</script>" (or "<!--", which starts HTML script-data
	# escape states) inert inside the <script> block. \u003c is the same
	# character once JSON.parse runs, so the round trip is exact.
	$payload = @{ name = [IO.Path]::GetFileName($CurtFile); text = $text }
	$lit = ConvertTo-Json -InputObject $payload -Compress
	$lit = $lit.Replace("<", "\u003c")

	$anchor = '<script src="curt-format.js"></script>'
	if (-not $html.Contains($anchor)) {
		throw "The viewer template changed shape - injection anchor not found. Re-sync viewer/index.html (see README)."
	}
	$inject = $anchor + "`r`n" + '<script>window.__OPENED_FILE=' + $lit + ';</script>'
	$html = $html.Replace($anchor, $inject)

	# Title the tab after the file, best effort.
	$oldTitle = '<title>View .curt — open a conversation file in the browser</title>'
	$newTitle = '<title>' + [IO.Path]::GetFileNameWithoutExtension($CurtFile) + ' — Curt Viewer</title>'
	$html = $html.Replace($oldTitle, $newTitle)

	# Write next to the .curt file; fall back to %TEMP% if that directory is
	# not writable. GetFileNameWithoutExtension caps the base name so a very
	# long .curt name still fits under the MAX_PATH limit.
	$base = [IO.Path]::GetFileNameWithoutExtension($CurtFile)
	if ($base.Length -gt 120) { $base = $base.Substring(0, 120) }
	$outName = "view-$base.html"
	$outPath = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($CurtFile))) $outName
	try {
		[IO.File]::WriteAllText((Get-LongPath $outPath), $html, (New-Object Text.UTF8Encoding($false)))
	} catch {
		$outPath = Join-Path $env:TEMP $outName
		[IO.File]::WriteAllText($outPath, $html, (New-Object Text.UTF8Encoding($false)))
	}

	if (-not $NoLaunch) {
		Start-Process -FilePath $outPath | Out-Null
	}
	exit 0
} catch {
	$msg = "Curt Viewer could not open this file:`r`n`r`n$($_.Exception.Message)"
	if (-not $NoDialog) {
		try {
			Add-Type -AssemblyName System.Windows.Forms
			[void][Windows.Forms.MessageBox]::Show($msg, "Curt Viewer")
		} catch {
			Write-Error $msg
		}
	} else {
		Write-Error $msg
	}
	exit 1
}
