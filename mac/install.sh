#!/bin/bash
# Install the .curt file association on macOS — current user only, no sudo.
#
# Builds "Curt Viewer.app" into ~/Applications, registers it with LaunchServices
# (lsregister -f), and — when the `duti` utility is present — sets it as the
# default handler for .curt / com.dotcurt.curt. Without duti, the app is
# registered and appears in Finder's "Open With" menu; the README explains
# the one-time "Change All..." step to make it the default.
#
# Usage: install.sh
set -euo pipefail

MACDIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Curt Viewer.app"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ "$(uname -s)" != "Darwin" ]; then
	echo "install.sh: this script is for macOS (uname says: $(uname -s))." >&2
	exit 1
fi
if ! command -v python3 >/dev/null 2>&1 && [ ! -x /usr/bin/python3 ]; then
	echo "python3 is required. On macOS run: xcode-select --install" >&2
	exit 1
fi

mkdir -p "$HOME/Applications"
"$MACDIR/make-app.sh" "$HOME/Applications"

if [ ! -x "$LSREG" ]; then
	echo "warning: lsregister not found at $LSREG — skipping LaunchServices registration." >&2
else
	"$LSREG" -f "$APP"
	echo "Registered with LaunchServices: $APP"
fi

if command -v duti >/dev/null 2>&1; then
	duti -s com.dotcurt.curt-viewer com.dotcurt.curt all
	duti -s com.dotcurt.curt-viewer .curt all
	echo "Set as default handler for .curt (via duti)."
	echo "Verify any time with: duti -x curt"
else
	echo ""
	echo "duti not found — the app is registered but not yet the default handler."
	echo "Either install duti (brew install duti) and re-run this script, or set"
	echo "the default once by hand:"
	echo "  1. In Finder, right-click a .curt file -> Get Info"
	echo "  2. Under 'Open with', choose 'Curt Viewer'"
	echo "  3. Click 'Change All...'"
fi

echo "Done. Double-click a .curt file to open it in the viewer."
