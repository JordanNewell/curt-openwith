#!/bin/sh
# Uninstall the .curt file association on Linux — current user only.
#
# Removes the desktop entry, the mime package, the default-handler line, and
# the installed copy under ~/.local/share/curt-openwith. Your .curt files and
# any generated view-*.html copies are untouched.
set -eu

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPDIR="$DATA/curt-openwith"
APPS="$DATA/applications"
MIME="$DATA/mime"
MIMEAPPS="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"

# Drop the default-handler line first (before the handler disappears).
if [ -f "$MIMEAPPS" ] && command -v xdg-mime >/dev/null 2>&1; then
	# xdg-mime has no "unset"; remove the association line ourselves.
	sed -i '/^application\/x-curt=curt-viewer\.desktop$/d' "$MIMEAPPS"
fi

rm -f "$APPS/curt-viewer.desktop" "$MIME/packages/x-curt.xml"
rm -rf "$APPDIR"

if command -v update-mime-database >/dev/null 2>&1; then
	update-mime-database "$MIME" 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$APPS" 2>/dev/null || true
fi

echo "Uninstalled. Your .curt files are untouched."
