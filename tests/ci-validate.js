// CI validation for a generated view-*.html — used by the macOS and Linux
// jobs in .github/workflows/qa.yml (and runnable anywhere node runs).
//
// Usage: node tests/ci-validate.js <view.html> [expected-stem]
//
// Checks the same invariants as tests/run-tests.js against the shared
// generator's output: the injected payload script is present, contains no
// raw '<' (the < escape invariant), JSON-round-trips losslessly, the
// tab title was swapped, no remote resources are auto-fetched, and the
// payload body parses through the vendored reference parseCurt
// (viewer/curt-format.js — no npm install, no network).
//
// Exit 0 = all checks passed, 1 = any failure, 2 = usage error.

"use strict";

const fs = require("fs");
const path = require("path");

const htmlPath = process.argv[2];
const expectStem = process.argv[3] || "";
if (!htmlPath) {
	console.error("usage: node tests/ci-validate.js <view.html> [expected-stem]");
	process.exit(2);
}

let failures = 0;
function check(name, ok, detail) {
	console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : "\n        " + detail}`);
	if (!ok) failures++;
}

const html = fs.readFileSync(htmlPath, "utf8");

// 1. The injected marker script is present exactly as the generator writes it.
const m = html.match(/<script>window\.__OPENED_FILE=([\s\S]*?);<\/script>/);
check("injected payload script present", !!m);
if (!m) process.exit(1);
const lit = m[1];

// 2. No raw '<' inside the literal — a smuggled </script> or <!-- must be
//    inert while the browser parses the HTML.
check("no raw '<' in injected literal (\\u003c escape invariant)", !lit.includes("<"));

// 3. JSON round trip: < decodes back to '<' losslessly on JSON.parse.
let payload;
try {
	payload = JSON.parse(lit);
} catch (e) {
	check("injected literal is valid JSON", false, e.message);
	process.exit(1);
}
check("injected literal is valid JSON", true);
check(
	"payload carries {name, text} with the .curt source name",
	!!payload && /\.curt$/.test(payload.name || "") && typeof payload.text === "string"
);

// 4. Tab title was swapped to "<stem> — Curt Viewer".
if (expectStem) {
	check(
		"tab title swapped to '<stem> — Curt Viewer'",
		html.includes("<title>" + expectStem + " — Curt Viewer</title>")
	);
}

// 5. Offline invariant (static proxy): no remote src= or url() references —
//    fonts/styles must resolve locally. Plain <a href> links to other pages
//    are fine; they never load on their own.
check(
	"no remote auto-fetched resources (src=/url() http[s])",
	!/src="https?:\/\//.test(html) && !/url\(['"]?https?:\/\//.test(html)
);

// 6. Real parse through the vendored reference implementation.
const src = fs.readFileSync(path.join(__dirname, "..", "viewer", "curt-format.js"), "utf8");
global.window = {};
new Function(src)();
const { parseCurt } = global.window.curtFormat;

// A corrupt body must be rejected cleanly — never half-parsed.
check("parser rejects corrupt input (returns null)", parseCurt("this is definitely not json") === null);

const conv = parseCurt(payload.text);
check("parseCurt accepts the payload body", !!conv);
if (conv && expectStem) {
	check("conversation title round-trips", conv.title === "CI fixture conversation");
}

if (failures) {
	console.log(`\n${failures} check(s) FAILED`);
	process.exit(1);
}
console.log("\nall ci-validate checks passed");
