#!/bin/bash
# Build "Curt Viewer.app" — a minimal, self-contained document handler for
# .curt files on macOS.
#
# The bundle carries its own copy of the shared generator and the vendored
# viewer, so the package folder can move or disappear after install. There is
# no compiled code: Contents/MacOS/curtopen is a shell script that LaunchServices
# invokes with the document path as argv[1]; it generates the HTML copy and
# hands it to the default browser via `open`.
#
# Usage: make-app.sh [output-dir]   (default: <package>/mac/build)
set -euo pipefail

MACDIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$MACDIR/.." && pwd)"
DEST="${1:-$MACDIR/build}"
APP="$DEST/Curt Viewer.app"

for f in "$PKG/viewer/index.html" "$PKG/viewer/curt-format.js" \
		 "$PKG/viewer/style.css" "$PKG/shared/curtopen-generator.py"; do
	if [ ! -f "$f" ]; then
		echo "make-app.sh: missing package file: $f" >&2
		exit 1
	fi
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" \
		 "$APP/Contents/Resources/viewer/fonts"

cp "$PKG/shared/curtopen-generator.py" "$APP/Contents/Resources/"
cp "$PKG/viewer/index.html" "$PKG/viewer/curt-format.js" "$PKG/viewer/style.css" \
   "$APP/Contents/Resources/viewer/"
cp "$PKG/viewer/fonts/"* "$APP/Contents/Resources/viewer/fonts/"

# ---------------------------------------------------------------- launcher --
cat > "$APP/Contents/MacOS/curtopen" <<'LAUNCHER'
#!/bin/bash
# Curt Viewer document handler. LaunchServices passes the .curt path as $1.
set -uo pipefail

RES="$(cd "$(dirname "$0")/.." && pwd)/Resources"
GEN="$RES/curtopen-generator.py"
VIEWER="$RES/viewer"

say_error() {
	# Best-effort alert; fall back to stderr when run from a terminal.
	# Double quotes in the message are escaped so they cannot break the
	# AppleScript string literal.
	local MSG="${1//\"/\\\"}"
	/usr/bin/osascript -e "display dialog \"Curt Viewer could not open this file:\n\n$MSG\" buttons {\"OK\"} default button 1 with title \"Curt Viewer\"" >/dev/null 2>&1 \
		|| echo "Curt Viewer could not open this file: $1" >&2
}

if [ $# -lt 1 ] || [ ! -f "$1" ]; then
	say_error "File not found${1:+: $1}"
	exit 1
fi
FILE="$1"
DIR="$(cd "$(dirname "$FILE")" && pwd)"
BASE="$(basename "$FILE")"
STEM="${BASE%.*}"
STEM="$(printf '%s' "$STEM" | cut -c 1-120)"

# Prefer a copy next to the .curt file; fall back to the system temp dir.
OUT=""
if touch "$DIR/.curtopen-write-test" 2>/dev/null; then
	rm -f "$DIR/.curtopen-write-test"
	OUT="$DIR/view-$STEM.html"
else
	OUT="${TMPDIR:-/tmp}/view-$STEM.html"
fi

ERR="$(mktemp "${TMPDIR:-/tmp}/curtopen-err.XXXXXX")" || exit 1
trap 'rm -f "$ERR"' EXIT
if ! /usr/bin/python3 "$GEN" "$FILE" "$OUT" "$VIEWER" 2>"$ERR"; then
	MSG="$(tr '\n' ' ' < "$ERR")"
	[ -n "$MSG" ] || MSG="the generator failed."
	rm -f "$OUT"
	say_error "$MSG"
	exit 1
fi

exec /usr/bin/open "$OUT"
LAUNCHER
chmod +x "$APP/Contents/MacOS/curtopen"

# -------------------------------------------------------------- Info.plist --
# Modern document-type keys: CFBundleDocumentTypes entries reference the UTI
# via LSItemContentTypes (CFBundleTypeExtensions is the deprecated pre-10.6
# form), and the UTI itself is declared under UTImportedTypeDeclarations —
# "imported" because another product (curt / dotcurt) owns the identifier.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleName</key>
	<string>Curt Viewer</string>
	<key>CFBundleDisplayName</key>
	<string>Curt Viewer</string>
	<key>CFBundleExecutable</key>
	<string>curtopen</string>
	<key>CFBundleIdentifier</key>
	<string>com.dotcurt.curt-viewer</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.13</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<true/>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Curtis conversation</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Default</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.dotcurt.curt</string>
			</array>
		</dict>
	</array>
	<key>UTImportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeIdentifier</key>
			<string>com.dotcurt.curt</string>
			<key>UTTypeDescription</key>
			<string>Curtis conversation</string>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.json</string>
			</array>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>curt</string>
				</array>
				<key>public.mime-type</key>
				<array>
					<string>application/x-curt</string>
				</array>
			</dict>
		</dict>
	</array>
</dict>
</plist>
PLIST

echo "Built: $APP"
