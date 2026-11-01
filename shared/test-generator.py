#!/usr/bin/env python3
# curt-openwith generator tests (macOS + Linux side).
#
# Runs the real shared generator (curtopen-generator.py) over three fixtures —
# a valid .curt conversation (same envelope the reference curt-format package
# serializes), the same conversation with "</script>" smuggled into a message
# body, and an invalid-JSON file — and verifies the generated HTML. When node
# and the reference curt-format package are available, it additionally
# round-trips the decoded body through the real parseCurt.
#
# Run:  python3 shared/test-generator.py
# (Everything is stdlib; the node round-trip is skipped if node or
# curt-format is missing, and reported as SKIP.)

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PKG = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GENERATOR = os.path.join(PKG, "shared", "curtopen-generator.py")
VIEWER_DIR = os.path.join(PKG, "viewer")

# Reference parser, used only for the optional node round-trip.
CURT_FORMAT_DIR = os.environ.get(
	"CURT_FORMAT_DIR",
	r"E:\dev\projects\curt-convert\node_modules\curt-format",
)

failures = 0
def check(name, ok, detail=""):
	global failures
	print("  %s  %s%s" % ("PASS" if ok else "FAIL", name,
						  "" if ok or not detail else "\n        " + detail))
	if not ok:
		failures += 1


def make_conversation(title, conv_id):
	t0 = 1760000000000
	return {
		"id": conv_id,
		"title": title,
		"createdAt": t0,
		"updatedAt": t0 + 12000,
		"messages": [
			{"id": "m1", "role": "system", "content": "You are a terse test fixture.", "timestamp": t0},
			{"id": "m2", "role": "user", "content": "Say hello, with spaces in the path in mind.", "timestamp": t0 + 1000},
			{"id": "m3", "role": "assistant",
			 "content": "Hello. The file lives at a path with spaces; that changes nothing.",
			 "timestamp": t0 + 11000, "model": "fixture-model-1"},
		],
	}


def serialize_curt(conversation, generator):
	# Same envelope the reference curt-format serializeCurt emits (verified
	# against curt-format's own output during development).
	return json.dumps({
		"curt": "curtis-conversation",
		"version": 1,
		"conversation": conversation,
		"generator": generator,
	}, indent="\t") + "\n"


def run_generator(curt_path, out_path):
	res = subprocess.run(
		[sys.executable, GENERATOR, curt_path, out_path, VIEWER_DIR],
		capture_output=True, text=True,
	)
	return res.returncode, (res.stderr or "").strip()


def extract_injected(html):
	m = re.search(r"<script>window\.__OPENED_FILE=([\s\S]*?);</script>", html)
	return m.group(1) if m else None


def node_roundtrip(lit_or_text, mode):
	# Requires node + the reference curt-format package. Returns (ok, result).
	if shutil.which("node") is None or not os.path.isdir(CURT_FORMAT_DIR):
		return None, "node or curt-format not available"
	require_path = os.path.join(CURT_FORMAT_DIR, "dist", "index.js").replace("\\", "/")
	# The program goes in on stdin ("node -"): multi-line -e arguments are
	# silently mangled by some Windows node shims (Volta). With "node -",
	# process.argv is [node, "-", <first user arg>].
	js = (
		'const { parseCurt } = require(%s);\n'
		'let input = process.argv[2];\n'
		'let out;\n'
		'if (process.argv[3] === "json") input = JSON.parse(input).text;\n'
		'out = parseCurt(input);\n'
		'if (out === null) { console.log("NULL"); } else { console.log(out.title); }\n'
	) % (json.dumps(require_path),)
	res = subprocess.run(["node", "-", lit_or_text, mode],
						 input=js, capture_output=True, text=True)
	if res.returncode != 0:
		return False, (res.stderr or "").strip()
	return True, (res.stdout or "").strip()


def main():
	work = tempfile.mkdtemp(prefix="curt-openwith-gen-test-")
	# A subdir name with spaces on purpose: the whole flow must survive them.
	fixtures = os.path.join(work, "fixture dir with spaces")
	os.makedirs(fixtures)

	valid_conv = make_conversation("Valid fixture conversation", "conv_fixture_0001")
	valid_json = serialize_curt(valid_conv, "curt-openwith-gen-tests@1.0.0")

	smuggle_conv = make_conversation("Smuggled close-tag fixture", "conv_fixture_0002")
	smuggle_conv["messages"][2]["content"] = (
		'Trying to escape: </script><script>window.__pwned=1</script>'
		" and a comment <!-- <script> trap")
	smuggle_json = serialize_curt(smuggle_conv, "curt-openwith-gen-tests@1.0.0")

	invalid_json = "{ this is not json at all }}}"

	names = {
		"valid": "valid.conversation.curt",
		"smuggle": "smuggled close tag.curt",
		"invalid": "invalid.curt",
	}
	with open(os.path.join(fixtures, names["valid"]), "w", encoding="utf-8", newline="") as fh:
		fh.write(valid_json)
	with open(os.path.join(fixtures, names["smuggle"]), "w", encoding="utf-8", newline="") as fh:
		fh.write(smuggle_json)
	with open(os.path.join(fixtures, names["invalid"]), "w", encoding="utf-8", newline="") as fh:
		fh.write(invalid_json)
	print("fixtures in: %s\n" % fixtures)

	# --- generator over each fixture ---------------------------------------
	for key, expect_valid in (("valid", True), ("smuggle", True), ("invalid", False)):
		print("fixture: %s" % names[key])
		curt_path = os.path.join(fixtures, names[key])
		out_path = os.path.join(fixtures, "view-" + names[key][:-5] + ".html")

		code, err = run_generator(curt_path, out_path)
		check("generator exits 0", code == 0, "exit=%s stderr=%s" % (code, err))
		if code != 0:
			continue
		check("view-*.html written next to the .curt file", os.path.isfile(out_path))
		with open(out_path, "r", encoding="utf-8", newline="") as fh:
			html = fh.read()

		lit = extract_injected(html)
		check("injected __OPENED_FILE block present", lit is not None)
		if lit is None:
			continue

		# Escape invariant: no raw '<' anywhere inside the injected JSON
		# literal — a smuggled "</script>" or "<!--" cannot terminate the
		# script block or enter script-data-escape states.
		check("no raw '<' inside the injected JSON literal", "<" not in lit)
		try:
			payload = json.loads(lit)
			check("injected literal parses as JSON", True)
		except ValueError as exc:
			check("injected literal parses as JSON", False, str(exc))
			continue
		check("payload.name carries the original file name",
			  payload["name"] == names[key], repr(payload["name"]))
		with open(curt_path, "r", encoding="utf-8", newline="") as fh:
			src_text = fh.read()
		check("payload.text round-trips the file exactly", payload["text"] == src_text)

		if key == "smuggle":
			check("decoded text keeps the smuggled </script> and full payload intact",
				  "</script><script>window.__pwned=1</script>" in payload["text"]
				  and "<!-- <script> trap" in payload["text"])

		if expect_valid:
			rt_ok, rt_val = node_roundtrip(lit, "json")
			if rt_ok is None:
				check("parseCurt round-trip (node)", True, "SKIP: %s" % rt_val)
			else:
				check("parseCurt accepts the decoded body (node)", rt_ok and rt_val != "NULL", rt_val)
				want = valid_conv["title"] if key == "valid" else smuggle_conv["title"]
				check("parsed conversation title matches the fixture", rt_val == want,
					  "%r != %r" % (rt_val, want))
		else:
			try:
				json.loads(payload["text"])
				check("invalid fixture: decoded body is not JSON (page shows its error path)", False)
			except ValueError:
				check("invalid fixture: decoded body is not JSON (page shows its error path)", True)
			check("error-box markup present for the error path",
				  'id="errorBox"' in html and 'id="errorMsg"' in html)
			check("magic string absent from an invalid body",
				  "curtis-conversation" not in payload["text"])

		# The injected block sits right after the vendored bundle tag, before
		# the module script runs (modules are deferred, so ordering holds).
		anchor_idx = html.find('<script src="curt-format.js"></script>')
		inject_idx = html.find("<script>window.__OPENED_FILE=")
		module_idx = html.find('<script type="module">')
		check("injection lands after the bundle and before the module script",
			  -1 < anchor_idx < inject_idx < module_idx,
			  "anchor=%s inject=%s module=%s" % (anchor_idx, inject_idx, module_idx))
		# Tab title swapped for a non-invalid fixture.
		if expect_valid:
			stem = names[key][:-5]
			check("tab title carries the file stem", ("<title>%s — Curt Viewer</title>" % stem) in html)
		print("")

	# --- misc generator behaviors -------------------------------------------
	print("generator behaviors")
	code, _ = run_generator(os.path.join(fixtures, "does-not-exist.curt"),
							os.path.join(fixtures, "view-does-not-exist.html"))
	check("missing file: nonzero exit, no HTML written",
		  code != 0 and not os.path.isfile(os.path.join(fixtures, "view-does-not-exist.html")))

	# Re-running the same file overwrites its view HTML cleanly.
	curt_path = os.path.join(fixtures, names["valid"])
	out_path = os.path.join(fixtures, "view-valid.conversation.html")
	with open(out_path, "r", encoding="utf-8", newline="") as fh:
		before = fh.read()
	with open(curt_path, "w", encoding="utf-8", newline="") as fh:
		fh.write(valid_json.replace("Valid fixture conversation", "Valid fixture conversation, edited"))
	code, _ = run_generator(curt_path, out_path)
	with open(out_path, "r", encoding="utf-8", newline="") as fh:
		after = fh.read()
	check("re-open overwrites the previous view HTML",
		  code == 0 and after != before and "edited" in after)

	# UTF-16LE BOM file decodes and still round-trips.
	u16_path = os.path.join(fixtures, "utf16 bom.curt")
	with open(u16_path, "wb") as fh:
		fh.write(b"\xff\xfe" + valid_json.encode("utf-16-le"))
	u16_out = os.path.join(fixtures, "view-utf16 bom.html")
	code, err = run_generator(u16_path, u16_out)
	if code == 0 and os.path.isfile(u16_out):
		with open(u16_out, "r", encoding="utf-8", newline="") as fh:
			lit = extract_injected(fh.read())
		payload = json.loads(lit) if lit else {}
		check("UTF-16LE BOM file decodes and round-trips",
			  payload.get("text") == valid_json and payload.get("name") == "utf16 bom.curt")
	else:
		check("UTF-16LE BOM file decodes and round-trips", False, "exit=%s %s" % (code, err))

	print("")
	if failures == 0:
		print("ALL TESTS PASS")
		sys.exit(0)
	print("%d FAILURE(S)" % failures)
	sys.exit(1)


if __name__ == "__main__":
	main()
