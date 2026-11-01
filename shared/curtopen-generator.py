#!/usr/bin/env python3
# curt-openwith shared generator (macOS + Linux).
#
# Builds a self-contained HTML copy of the offline viewer with a .curt file's
# JSON body injected as window.__OPENED_FILE, so the page renders the
# conversation on load. One implementation, called by both mac/curtopen.sh and
# linux/curtopen.sh (and by the macOS .app bundle's launcher). stdlib only.
#
# Usage:
#   curtopen-generator.py <in.curt> <out.html> <viewer-dir>
#
# The injected block and the escaping rules are byte-shape-identical to the
# Windows generator (curtopen.ps1): the payload is a compact JSON literal
# {"name":...,"text":...} with every '<' rewritten to '<' so a smuggled
# "</script>" (or "<!--") cannot terminate or escape the <script> block.
# '<' decodes back to '<' exactly when JSON.parse runs — the round trip
# is lossless. See README.md and tests/.
#
# Exit codes: 0 on success, 1 on any failure (reason printed to stderr).

import json
import os
import sys
from typing import NoReturn

# Injection anchor: the vendored bundle tag inside viewer/index.html. The
# injected script must land right after it and before the module script
# (modules are deferred, so ordering holds at runtime).
ANCHOR = '<script src="curt-format.js"></script>'

# Best-effort tab-title swap; matched verbatim against the synced viewer.
OLD_TITLE = '<title>View .curt — open a conversation file in the browser</title>'


def fail(msg) -> NoReturn:
	sys.stderr.write("Curt Viewer could not open this file:\n\n%s\n" % msg)
	sys.exit(1)


def decode_text(raw):
	# BOM-aware decode, mirroring what the viewer's own drop handler does
	# (UTF-16LE/BE first, then assume UTF-8). Invalid UTF-8 decodes with
	# U+FFFD replacements, matching the Windows generator's .NET behavior;
	# the page's own validator then rejects the body cleanly.
	if raw[:2] == b"\xff\xfe":
		return raw[2:].decode("utf-16-le", errors="replace")
	if raw[:2] == b"\xfe\xff":
		return raw[2:].decode("utf-16-be", errors="replace")
	return raw.decode("utf-8", errors="replace")


def build_html(curt_path, viewer_dir):
	viewer_path = os.path.join(viewer_dir, "index.html")
	if not os.path.isfile(viewer_path):
		fail("The viewer template is missing: %s (did the package get moved "
			 "without its viewer folder?)" % viewer_path)
	try:
		with open(viewer_path, "r", encoding="utf-8", newline="") as fh:
			html = fh.read()
	except OSError as exc:
		fail("Could not read the viewer template: %s" % exc)

	try:
		with open(curt_path, "rb") as fh:
			raw = fh.read()
	except OSError as exc:
		fail("Could not read the file: %s" % exc)
	text = decode_text(raw)

	# Inject the file as window.__OPENED_FILE = {name, text}. json.dumps with
	# ensure_ascii escapes non-ASCII to \uXXXX (same as the Windows
	# generator); replacing every '<' with < afterwards makes any
	# smuggled "</script>" (or "<!--") inert inside the <script> block.
	payload = {"name": os.path.basename(curt_path), "text": text}
	lit = json.dumps(payload, ensure_ascii=True, separators=(",", ":"))
	lit = lit.replace("<", "\\u003c")

	if ANCHOR not in html:
		fail("The viewer template changed shape - injection anchor not found. "
			 "Re-sync viewer/index.html (see README).")
	inject = ANCHOR + "\n" + '<script>window.__OPENED_FILE=' + lit + ';</script>'
	html = html.replace(ANCHOR, inject)

	# Title the tab after the file, best effort (strip the last extension,
	# matching the Windows generator's GetFileNameWithoutExtension).
	base = os.path.basename(curt_path)
	stem = base.rsplit(".", 1)[0] if "." in base else base
	new_title = "<title>" + stem + " — Curt Viewer</title>"
	html = html.replace(OLD_TITLE, new_title)
	return html


def main(argv):
	if len(argv) != 4:
		sys.stderr.write(
			"usage: curtopen-generator.py <in.curt> <out.html> <viewer-dir>\n")
		sys.exit(2)
	curt_path, out_path, viewer_dir = argv[1], argv[2], argv[3]

	if not os.path.isfile(curt_path):
		fail("File not found: %s" % curt_path)

	html = build_html(curt_path, viewer_dir)

	try:
		# UTF-8, no BOM — same as the Windows generator's output.
		with open(out_path, "w", encoding="utf-8", newline="") as fh:
			fh.write(html)
	except OSError as exc:
		fail("Could not write the viewer copy: %s" % exc)
	sys.exit(0)


if __name__ == "__main__":
	main(sys.argv)
