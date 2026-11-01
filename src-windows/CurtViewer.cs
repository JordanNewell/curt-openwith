// CurtViewer.exe — the native Windows front door for curt-openwith.
//
// Sibling layout: this exe must sit next to curtopen.ps1 (the zip ships it
// that way). It forwards every argument to powershell.exe running the ps1
// with no window of its own (CreateNoWindow), so double-clicking a .curt
// file shows no console flash — only the ps1's own error dialog when
// something is actually wrong — and the ps1's exit code comes straight back
// as this process's exit code.
//
// Built by build.cmd with the .NET Framework compiler that ships in every
// Windows install; no SDK, no downloads.

using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class CurtViewer
{
	[STAThread]
	private static int Main(string[] args)
	{
		// Resolve our own directory (works regardless of the current working
		// directory, which Explorer sets to the .curt file's folder).
		string exeDir = AppDomain.CurrentDomain.BaseDirectory;
		string ps1 = Path.Combine(exeDir, "curtopen.ps1");

		if (!File.Exists(ps1))
		{
			// Same tone as the ps1's own error dialog: plain statement of
			// what failed and the one fix that matters.
			MessageBox.Show(
				"Curt Viewer could not open this file:\r\n\r\n" +
				"curtopen.ps1 was not found next to CurtViewer.exe. " +
				"Re-extract the package so CurtViewer.exe and curtopen.ps1 " +
				"sit in the same folder, then run install.cmd again.",
				"Curt Viewer",
				MessageBoxButtons.OK,
				MessageBoxIcon.Error);
			return 1;
		}

		ProcessStartInfo psi = new ProcessStartInfo();
		psi.FileName = "powershell.exe";
		psi.Arguments = BuildArguments(ps1, args);
		psi.UseShellExecute = false;
		psi.CreateNoWindow = true;

		using (Process p = Process.Start(psi))
		{
			p.WaitForExit();
			return p.ExitCode;
		}
	}

	// -NoProfile -NonInteractive keep the host quiet and non-interactive;
	// every user argument is forwarded verbatim (quoted), so the ps1's
	// -NoLaunch switch and any future flags still work from the command line.
	private static string BuildArguments(string ps1, string[] args)
	{
		System.Text.StringBuilder sb = new System.Text.StringBuilder();
		sb.Append("-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ");
		sb.Append(Quote(ps1));
		foreach (string arg in args)
		{
			sb.Append(' ');
			sb.Append(Quote(arg));
		}
		return sb.ToString();
	}

	// Standard Windows command-line quoting: wrap in quotes, double up any
	// embedded quotes (file paths never contain them, but forward safely
	// anyway).
	private static string Quote(string s)
	{
		return "\"" + s.Replace("\"", "\"\"") + "\"";
	}
}
