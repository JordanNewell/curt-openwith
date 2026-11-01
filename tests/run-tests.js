// curt-openwith test suite. Exercises the real generator (curtopen.ps1) in a
// temp dir — with -NoLaunch so no browser opens and nothing touches the
// registry — and verifies the generated HTML by extracting the injected
// JSON and round-tripping it through the reference parser.
//
// Run: node tests/run-tests.js

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const { serializeCurt, parseCurt, CURT_MAGIC } = require("E:/dev/projects/curt-convert/node_modules/curt-format");

const PKG = path.resolve(__dirname, "..");
const PS1 = path.join(PKG, "curtopen.ps1");

let failures = 0;
function check(name, ok, detail) {
	console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : "\n        " + detail}`);
	if (!ok) failures++;
}

function makeConversation(title, id) {
	const t0 = 1760000000000;
	return {
		id,
		title,
		createdAt: t0,
		updatedAt: t0 + 12000,
		messages: [
			{ id: "m1", role: "system", content: "You are a terse test fixture.", timestamp: t0 },
			{ id: "m2", role: "user", content: "Say hello, with spaces in the path in mind.", timestamp: t0 + 1000 },
			{
				id: "m3",
				role: "assistant",
				content: "Hello. The file lives at a path with spaces; that changes nothing.",
				timestamp: t0 + 11000,
				model: "fixture-model-1",
			},
		],
	};
}

function runGenerator(curtPath, outDir) {
	// No explicit cwd: paths are absolute, and CreateProcess rejects a
	// lpCurrentDirectory over MAX_PATH — long-path support lives in the
	// generator, not in where the test happens to run from.
	void outDir;
	const res = spawnSync(
		"powershell.exe",
		["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", PS1, curtPath, "-NoLaunch"],
		{ encoding: "utf8" }
	);
	return { code: res.status, stderr: (res.stderr || "").trim() };
}

// Extract the injected payload from the generated HTML. The marker script is
// the only one matching `window.__OPENED_FILE=` at build time.
function extractInjected(html) {
	const m = html.match(/<script>window\.__OPENED_FILE=([\s\S]*?);<\/script>/);
	return m ? m[1] : null;
}

function main() {
	const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "curt-openwith-test-"));
	// A subdir name with spaces on purpose: the whole flow must survive them.
	const fixturesDir = path.join(workDir, "fixture dir with spaces");
	fs.mkdirSync(fixturesDir);

	// --- fixtures ----------------------------------------------------------
	const validConv = makeConversation("Valid fixture conversation", "conv_fixture_0001");
	const validJson = serializeCurt(validConv, "curt-openwith-tests@1.0.0");

	const smuggleConv = makeConversation("Smuggled close-tag fixture", "conv_fixture_0002");
	smuggleConv.messages[2].content =
		'Trying to escape: </script><script>window.__pwned=1</script> and a comment <!-- <script> trap';
	const smuggleJson = serializeCurt(smuggleConv, "curt-openwith-tests@1.0.0");

	const invalidJson = "{ this is not json at all }}}";

	fs.writeFileSync(path.join(fixturesDir, "valid.conversation.curt"), validJson, "utf8");
	fs.writeFileSync(path.join(fixturesDir, "smuggled close tag.curt"), smuggleJson, "utf8");
	fs.writeFileSync(path.join(fixturesDir, "invalid.curt"), invalidJson, "utf8");
	console.log(`fixtures in: ${fixturesDir}\n`);

	// --- generator over each fixture ---------------------------------------
	for (const [fixture, expectValid] of [
		["valid.conversation.curt", true],
		["smuggled close tag.curt", true],
		["invalid.curt", false],
	]) {
		console.log(`fixture: ${fixture}`);
		const curtPath = path.join(fixturesDir, fixture);
		const outHtmlPath = path.join(fixturesDir, "view-" + fixture.replace(/\.curt$/i, "") + ".html");

		const run = runGenerator(curtPath, fixturesDir);
		check("generator exits 0", run.code === 0, `exit=${run.code} stderr=${run.stderr}`);
		if (run.code !== 0) continue;
		check("view-*.html written next to the .curt file", fs.existsSync(outHtmlPath));

		const html = fs.readFileSync(outHtmlPath, "utf8");
		const lit = extractInjected(html);
		check("injected __OPENED_FILE block present", lit !== null);
		if (lit === null) continue;

		// Escape invariant: no raw '<' anywhere inside the injected JSON
		// literal — a smuggled "</script>" or "<!--" cannot terminate the
		// script block or enter script-data-escape states.
		check("no raw '<' inside the injected JSON literal", !lit.includes("<"));

		let payload;
		try {
			payload = JSON.parse(lit);
		} catch (e) {
			check("injected literal parses as JSON", false, String(e));
			continue;
		}
		check("injected literal parses as JSON", true);
		check("payload.name carries the original file name", payload.name === fixture, JSON.stringify(payload.name));

		// Round trip: the decoded text must be byte-identical to the source.
		check("payload.text round-trips the file exactly", payload.text === fs.readFileSync(curtPath, "utf8"));

		// The decoded text still contains the smuggled markup (nothing was
		// mangled — it is escaped only while embedded in HTML).
		if (fixture.startsWith("smuggled")) {
			check(
				"decoded text keeps the smuggled </script> and full payload intact",
				payload.text.includes("</script><script>window.__pwned=1</script>") && payload.text.includes("<!-- <script> trap")
			);
		}

		if (expectValid) {
			const parsed = parseCurt(payload.text);
			check("parseCurt accepts the decoded body", parsed !== null);
			check(
				"parsed conversation matches the fixture",
				parsed !== null && parsed.title === (fixture.startsWith("valid") ? validConv.title : smuggleConv.title)
			);
		} else {
			let threw = false;
			try {
				JSON.parse(payload.text);
			} catch {
				threw = true;
			}
			check("invalid fixture: decoded body is not JSON (page shows its error path)", threw);
			// The page's own error markup ships in every generated copy.
			check("error-box markup present for the error path", html.includes('id="errorBox"') && html.includes('id="errorMsg"'));
			check("magic string absent from an invalid body", !payload.text.includes(CURT_MAGIC));
		}

		// The injected block sits right after the vendored bundle tag, before
		// the module script runs (modules are deferred, so ordering holds).
		const anchorIdx = html.indexOf('<script src="curt-format.js"></script>');
		const injectIdx = html.indexOf("<script>window.__OPENED_FILE=");
		const moduleIdx = html.indexOf('<script type="module">');
		check("injection lands after the bundle and before the module script", anchorIdx > -1 && injectIdx > anchorIdx && moduleIdx > injectIdx);
		console.log("");
	}

	// --- misc generator behaviors -------------------------------------------
	console.log("generator behaviors");
	{
		const run = runGenerator(path.join(fixturesDir, "does-not-exist.curt"), fixturesDir);
		check("missing file: nonzero exit, no HTML written", run.code !== 0 && !fs.existsSync(path.join(fixturesDir, "view-does-not-exist.html")));
	}
	{
		// Re-running the same file overwrites its view HTML cleanly.
		const curtPath = path.join(fixturesDir, "valid.conversation.curt");
		const outHtmlPath = path.join(fixturesDir, "view-valid.conversation.html");
		const before = fs.readFileSync(outHtmlPath, "utf8");
		fs.writeFileSync(curtPath, validJson.replace("Valid fixture conversation", "Valid fixture conversation, edited"), "utf8");
		const run = runGenerator(curtPath, fixturesDir);
		const after = fs.readFileSync(outHtmlPath, "utf8");
		check("re-open overwrites the previous view HTML", run.code === 0 && after !== before && after.includes("edited"));
	}

	// --- long path (>248 chars) ---------------------------------------------
	console.log("long path");
	{
		// Build a directory chain deep enough that the .curt path exceeds the
		// 248-char mark where plain Win32 paths give up.
		let deep = path.join(workDir, "deep-path");
		for (let i = 0; i < 6; i++) deep = path.join(deep, "segment-with-a-40-char-name-0123456789abcd" + i);
		fs.mkdirSync(deep, { recursive: true });
		const curtPath = path.join(deep, "longpath.curt");
		fs.writeFileSync(curtPath, validJson, "utf8");
		check("fixture path is actually over the 248-char mark", curtPath.length > 248, `len=${curtPath.length}`);

		const run = runGenerator(curtPath, deep);
		check("generator exits 0 on a long path", run.code === 0, `exit=${run.code} stderr=${run.stderr}`);
		const outHtmlPath = path.join(deep, "view-longpath.html");
		if (run.code === 0 && fs.existsSync(outHtmlPath)) {
			const payload = JSON.parse(extractInjected(fs.readFileSync(outHtmlPath, "utf8")));
			check("long path: injected payload round-trips", payload.text === validJson);
		} else {
			check("long path: view HTML written", false);
		}
	}

	console.log(failures === 0 ? "\nALL TESTS PASS" : `\n${failures} FAILURE(S)`);
	process.exit(failures === 0 ? 0 : 1);
}

main();
