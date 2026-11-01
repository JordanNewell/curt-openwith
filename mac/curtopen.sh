#!/bin/sh
# curt-openwith (macOS): open a .curt file in the offline Curt Viewer.
#
# Wraps the shared generator, then `open`s the generated HTML in the default
# browser. This copy works from the package layout (mac/ + ../viewer +
# ../shared); the installed artifact is "Curt Viewer.app" (see make-app.sh /
# install.sh), which bundles its own copy of everything it needs.
#
# Usage: curtopen.sh <file.curt>
set -eu

if [ $# -lt 1 ]; then
	echo "usage: curtopen.sh <file.curt>" >&2
	exit 2
fi
FILE="$1"
if [ ! -f "$FILE" ]; then
	echo "Curt Viewer could not open this file:" >&2
	echo "" >&2
	echo "File not found: $FILE" >&2
	exit 1
fi

# Resolve this script's directory through any symlink.
SCRIPT="$0"
while [ -L "$SCRIPT" ]; do
	LINK="$(readlink "$SCRIPT")"
	case "$LINK" in
		/*) SCRIPT="$LINK" ;;
		*) SCRIPT="$(dirname "$SCRIPT")/$LINK" ;;
	esac
done
PKG="$(cd "$(dirname "$SCRIPT")/.." && pwd)"

GEN=""
VIEWER=""
# Installed-flat layout (everything side by side) first, then package layout.
for c in "$PKG/curtopen-generator.py" "$PKG/shared/curtopen-generator.py"; do
	if [ -f "$c" ]; then GEN="$c"; break; fi
done
for c in "$PKG/viewer" "$PKG/../viewer"; do
	if [ -f "$c/index.html" ]; then VIEWER="$c"; break; fi
done
if [ -z "$GEN" ] || [ -z "$VIEWER" ]; then
	echo "Curt Viewer could not open this file:" >&2
	echo "" >&2
	echo "The generator or viewer template is missing from the package." >&2
	exit 1
fi

PYTHON="$(command -v python3 || true)"
if [ -z "$PYTHON" ]; then
	echo "python3 is required but was not found on PATH." >&2
	echo "On macOS: xcode-select --install provides /usr/bin/python3." >&2
	exit 1
fi

# Write view-<name>.html next to the .curt file (fall back to the system temp
# dir if that folder is not writable), capping the base name so long file
# names still fit.
DIR="$(cd "$(dirname "$FILE")" && pwd)"
BASE="$(basename "$FILE")"
STEM="${BASE%.*}"
STEM="$(printf '%s' "$STEM" | cut -c 1-120)"

OUT=""
if touch "$DIR/.curtopen-write-test" 2>/dev/null; then
	rm -f "$DIR/.curtopen-write-test"
	OUT="$DIR/view-$STEM.html"
else
	OUT="${TMPDIR:-/tmp}/view-$STEM.html"
fi

ERR="$(mktemp "${TMPDIR:-/tmp}/curtopen-err.XXXXXX")" || exit 1
trap 'rm -f "$ERR"' EXIT
if ! "$PYTHON" "$GEN" "$FILE" "$OUT" "$VIEWER" 2>"$ERR"; then
	echo "Curt Viewer could not open this file:" >&2
	echo "" >&2
	cat "$ERR" >&2
	rm -f "$OUT"
	exit 1
fi

exec open "$OUT"
