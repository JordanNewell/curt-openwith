# curt-openwith

Double-click a `.curt` file on Windows and it opens in the offline Curt
Viewer — a browser page that renders the conversation locally. No server, no
network, no install beyond a couple of registry keys under your user account.

## Install / uninstall

1. Extract this folder somewhere stable (the association points into it —
   don't delete it after installing).
2. Double-click `install.cmd`. It prints exactly what it writes: four values
   under `HKCU\Software\Classes` (`.curt` → `curtfile`, the class name, the
   "Open with Curt Viewer" verb label, and the open command pointing at
   `curtopen.cmd` in this folder). Current user only — no admin needed,
   nothing machine-wide, no files copied anywhere.
3. Double-click any `.curt` file.

`uninstall.cmd` deletes those same registry keys (your files are untouched).

Already-open Explorer windows may need a refresh (F5) to pick up the change.

## How it works

`curtopen.cmd` is the association target; it hands the file path to
`curtopen.ps1`, which:

1. Reads the `.curt` file (BOM-aware: UTF-8, UTF-16LE/BE).
2. Copies the bundled viewer (`viewer/index.html`, fully offline — styles and
   fonts vendored next to it) to `view-<name>.html` **next to your .curt
   file** (or `%TEMP%` if that folder isn't writable).
3. Injects the file's JSON body into that copy as

   ```html
   <script>window.__OPENED_FILE={"name":"...","text":"..."};</script>
   ```

4. Opens the generated HTML in your default browser.

The viewer page (an adjusted copy of the
[dot_curt](https://github.com/JordanNewell/dot_curt) site viewer) checks
`window.__OPENED_FILE` on load and runs the injected body through the exact
same validate-then-render path as a file dropped on the page — so a corrupt
or non-`.curt` file gets the same clean "Could not read this file" error box,
never a half-rendered transcript. All rendered content goes in via
`textContent`; nothing in a viewed file can execute.

### Why the injected block can't break out

Every `<` in the injected JSON string is rewritten to the escape `\u003c`
before it's written. That makes any smuggled `</script>` inert while the
browser parses the HTML (so a message containing `</script>` can't terminate
the script block early), and it also defuses `<!--`, which starts HTML
script-data escape states. Once the page's `JSON.parse` runs, `\u003c`
decodes back to `<` exactly — the round trip is lossless, tested in
`tests/run-tests.js`.

## Security note

The generated `view-*.html` file **contains a plain-text copy of the
conversation**. It's written to your own disk next to the source file (or
`%TEMP%`), rendered by the page, and that's all — the viewer is fully
offline, fetches nothing, and ships no analytics. Deleting the
`view-*.html` file erases the copy. If the conversation is sensitive,
remember the generated HTML persists after you close the browser tab.

## Provenance / re-syncing the viewer

`viewer/` is a standalone copy of `dot_curt/site/viewer/index.html` (branch
`viewer`) plus its stylesheet and fonts:

- synced at upstream commit
  `89b2659b14a4bcc26b9dbcae50290024fe6b1a50` (2026-11-01, "viewer: story box
  below transcript — blog post, episode audio, episode as .curt")
- `viewer/curt-format.js`, `viewer/style.css`, `viewer/fonts/*` are
  byte-identical to upstream; `index.html` carries exactly three adjustments,
  each tagged with a `curt-openwith` comment:
  1. `../style.css` → `style.css` (vendored locally)
  2. a `window.__OPENED_FILE` consumer at the end of the module script
  3. removal of site-only controls (nav, real-example/episode fetch buttons,
     story box) that need the dotcurt.org server or sibling pages

To re-sync: copy the new upstream `index.html` over `viewer/index.html`,
then re-apply the three tagged edits (search for `curt-openwith` in the
current file for the exact shape), and update the commit hash in the header
comment. Everything else in the package is viewer-agnostic.

## Testing

`node tests/run-tests.js` builds three fixture files (a valid conversation
serialized with the reference `curt-format` package; the same conversation
with `</script>` smuggled into a message body; an invalid-JSON file), runs
the real `curtopen.ps1` generator over each in a temp directory
(`-NoLaunch`, so no browser opens), and verifies the generated HTML by
parsing out the injected JSON, round-tripping it through `parseCurt`, and
checking the `\u003c-escape` invariant. It never touches the registry and never
launches a browser.

## Shipping

The whole folder is designed to zip as-is for a GitHub release (viewer +
scripts + this README; no build step). A scoop manifest can point at the
same zip and invoke `install.cmd` post-install — not built yet.

MIT — see `LICENSE`.
