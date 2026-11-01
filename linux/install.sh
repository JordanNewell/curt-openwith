#!/bin/sh
# Install the .curt file association on Linux — current user only, no sudo.
#
# Lands in your XDG user dirs:
#   ~/.local/share/curt-openwith/            self-contained copy (wrapper +
#                                            generator + vendored viewer)
#   ~/.local/share/applications/curt-viewer.desktop
#   ~/.local/share/mime/packages/x-curt.xml  (application/x-curt, *.curt)
# then refreshes the mime + desktop databases and sets the default handler
# via xdg-mime.
#
# Usage: install.sh
set -eu

LINUXDIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$LINUXDIR/.." && pwd)"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPDIR="$DATA/curt-openwith"
APPS="$DATA/applications"
MIME="$DATA/mime"

if [ "$(uname -s)" = "Darwin" ]; then
	echo "install.sh: this is the Linux installer; use mac/install.sh on macOS." >&2
	exit 1
fi
command -v python3 >/dev/null 2>&1 || {
	echo "python3 is required but was not found on PATH." >&2
	exit 1
}

for f in "$PKG/viewer/index.html" "$PKG/viewer/curt-format.js" \
		 "$PKG/viewer/style.css" "$PKG/shared/curtopen-generator.py" \
		 "$LINUXDIR/curtopen.sh" "$LINUXDIR/curt-viewer.desktop" \
		 "$LINUXDIR/x-curt.xml"; do
	if [ ! -f "$f" ]; then
		echo "install.sh: missing package file: $f" >&2
		exit 1
	fi
done

# ------------------------------------------------------------------ files --
mkdir -p "$APPDIR/viewer/fonts" "$APPS" "$MIME/packages"

install -m 0755 "$LINUXDIR/curtopen.sh"          "$APPDIR/curtopen.sh"
install -m 0755 "$PKG/shared/curtopen-generator.py" "$APPDIR/curtopen-generator.py"
install -m 0644 "$PKG/viewer/index.html"         "$APPDIR/viewer/index.html"
install -m 0644 "$PKG/viewer/curt-format.js"     "$APPDIR/viewer/curt-format.js"
install -m 0644 "$PKG/viewer/style.css"          "$APPDIR/viewer/style.css"
for font in "$PKG"/viewer/fonts/*; do
	[ -f "$font" ] && install -m 0644 "$font" "$APPDIR/viewer/fonts/"
done

# --------------------------------------------------------------- desktop --
# Rewrite Exec with the installed path, escaped per the Desktop Entry Spec
# (backslash-escape the reserved characters inside a double-quoted argument).
ESC="$(printf '%s' "$APPDIR/curtopen.sh" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/`/\\`/g' -e 's/\$/\\$/g')"
sed "s|@EXECPATH@|\"$ESC\"|" "$LINUXDIR/curt-viewer.desktop" \
	> "$APPS/curt-viewer.desktop"
chmod 0644 "$APPS/curt-viewer.desktop"

# ------------------------------------------------------------------ mime --
install -m 0644 "$LINUXDIR/x-curt.xml" "$MIME/packages/x-curt.xml"

# -------------------------------------------------------------- register --
if command -v update-mime-database >/dev/null 2>&1; then
	update-mime-database "$MIME"
fi
if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$APPS" || true
fi
if command -v xdg-mime >/dev/null 2>&1; then
	xdg-mime default curt-viewer.desktop application/x-curt
else
	echo "warning: xdg-mime not found — the default-handler line was not written." >&2
	echo "Add manually to ~/.config/mimeapps.list:" >&2
	echo "  application/x-curt=curt-viewer.desktop" >&2
fi

echo "Installed:"
echo "  $APPDIR"
echo "  $APPS/curt-viewer.desktop"
echo "  $MIME/packages/x-curt.xml"
echo "Done. Double-click a .curt file (or: xdg-open file.curt) to view it."
