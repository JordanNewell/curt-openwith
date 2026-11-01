#!/bin/bash
# Uninstall the .curt file association on macOS — current user only, no sudo.
#
# Unregisters the app with LaunchServices and deletes ~/Applications/Curt
# Viewer.app. Generated view-*.html copies are NOT touched (they live next to
# your .curt files; delete them by hand if you want them gone).
set -euo pipefail

APP="$HOME/Applications/Curt Viewer.app"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ "$(uname -s)" != "Darwin" ]; then
	echo "uninstall.sh: this script is for macOS (uname says: $(uname -s))." >&2
	exit 1
fi

if [ -d "$APP" ]; then
	if [ -x "$LSREG" ]; then
		"$LSREG" -u "$APP" || true
	fi
	rm -rf "$APP"
	echo "Removed: $APP"
else
	echo "Not installed (no $APP)."
fi

# Note: a duti-set default is just a LaunchServices preference; once the app
# is unregistered and deleted, LaunchServices falls back to the next
# registered handler automatically. No explicit reset is needed.

echo ""
echo "Note: if Finder still offers the deleted app in 'Open With' for a while,"
echo "that is LaunchServices' cache — it clears on its own, or immediately via:"
echo "  $LSREG -kill -r -domain local -domain system -domain user"
echo "(that rebuild can take a minute; only run it if the stale entry bothers you)"
echo "Uninstall complete. Your .curt files are untouched."
