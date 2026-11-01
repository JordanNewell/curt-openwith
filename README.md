# curt-openwith

Double-click a `.curt` file on Windows, macOS, or Linux and it opens in the
offline Curt Viewer — a browser page that renders the conversation locally.
No server, no network; installs only under your user account.

## Install

**Windows (Scoop)** — self-owned bucket:

```powershell
scoop bucket add jordannewell https://github.com/JordanNewell/bucket
scoop install curt-openwith
```

Scoop only unpacks the package; run `install.cmd` from the package folder
(`$(scoop prefix curt-openwith)`) to register the `.curt` handler.

**macOS / Linux (Homebrew)** — self-owned tap (installs the package folder;
the formula prints the registration step):

```sh
brew tap JordanNewell/tap https://github.com/JordanNewell/homebrew-tap
brew install curt-openwith
bash "$(brew --prefix curt-openwith)/libexec/mac/install.sh"   # macOS
bash "$(brew --prefix curt-openwith)/libexec/linux/install.sh" # Linux
```

**Manual** — download the release zip from
[GitHub Releases](https://github.com/JordanNewell/curt-openwith/releases)
and follow the platform steps below.

**winget** — a manifest for v1.0.1 is drafted but not yet submitted.

## Install / uninstall

1. Extract this folder somewhere stable (the association points into it —
   don't delete it after installing).
2. Double-click `install.cmd`. It registers `CurtViewer.exe` — the native
   launcher, which opens `.curt` files with no console flash — building it
   on the spot from `src-windows\CurtViewer.cs` with the C# compiler Windows
   ships in the box if the exe isn't present yet. If neither the exe nor a
   compiler is available it falls back to the `curtopen.cmd` wrapper (same
   behavior; a console window flashes briefly on each open). It prints
   exactly what it writes: four values under `HKCU\Software\Classes`
   (`.curt` → `curtfile`, the class name, the "Open with Curt Viewer" verb
   label, and the open command pointing at the handler in this folder).
   Current user only — no admin needed, nothing machine-wide, no files
   copied anywhere.
3. Double-click any `.curt` file.

`uninstall.cmd` deletes those same registry keys (your files are untouched).

Already-open Explorer windows may need a refresh (F5) to pick up the change.

Upgrading: extract the new package over (or next to) the old one and re-run
`install.cmd` so the registered path picks up the new folder.

## macOS install / uninstall

1. Extract this folder somewhere stable and run `mac/install.sh` from a
   terminal. It builds `Curt Viewer.app` into `~/Applications`, registers it
   with LaunchServices (`lsregister -f`), and — if the `duti` utility is
   installed (`brew install duti`) — sets it as the default handler for
   `.curt`. Without `duti`, the app still appears in Finder's Open With menu;
   make it the default once by hand (Get Info → Open with → Curt Viewer →
   Change All...).
2. Double-click any `.curt` file.

`mac/uninstall.sh` unregisters and deletes `~/Applications/Curt Viewer.app`.
Current user only — no sudo, nothing outside your home directory. Requires
python3 (macOS provides it via Command Line Tools: `xcode-select --install`).

## Linux install / uninstall

1. Extract this folder and run `linux/install.sh`. It installs a
   self-contained copy to `~/.local/share/curt-openwith/`, plus
   `curt-viewer.desktop` in `~/.local/share/applications/` and the
   `application/x-curt` mime type (`x-curt.xml`, glob `*.curt`) in
   `~/.local/share/mime/packages/`, then refreshes the mime and desktop
   databases and runs `xdg-mime default curt-viewer.desktop application/x-curt`.
2. Double-click a `.curt` file in your file manager, or `xdg-open file.curt`.

`linux/uninstall.sh` removes all of it (including the default-handler line).
Current user only — no sudo. Requires python3.

Both platforms share one generator, `shared/curtopen-generator.py`
(python3, stdlib only), and ship their own copy of the viewer; the installed
artifact is self-contained, so the original extracted folder can be deleted
after installing.

## How it works

On Windows the association target is `CurtViewer.exe`, a ~6 KB native
launcher built by `build.cmd` from `src-windows\CurtViewer.cs` (source
shipped in the package — the exe is reproducible from that script alone,
using the .NET Framework C# compiler at
`C:\Windows\Microsoft.NET\...\v4.0.30319\csc.exe` that every Windows install
already has; no SDK, no downloads). It resolves its own directory, requires
`curtopen.ps1` as a sibling, forwards every argument to

```
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File curtopen.ps1 <args>
```

with `CreateNoWindow` set (so double-clicking a `.curt` file shows no
console flash — the ps1's friendly error dialog still surfaces when
something is actually wrong), and passes the script's exit code straight
through. If `curtopen.ps1` is missing it says so in a plain MessageBox.

`curtopen.cmd` is the older wrapper around the same script and remains the
fallback when no compiler is available. On macOS and Linux the association
target is `Curt Viewer.app`
/ `curt-viewer.desktop`, which invoke the shell wrappers (`mac/curtopen.sh`,
`linux/curtopen.sh`) around the same logic. On every platform the generator:

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
checking the `\u003c-escape` invariant. It then compiles `CurtViewer.exe` via `build.cmd` and
exercises it end to end: the exe must exist after the build, must open a
spaces-in-path fixture into a generated `view-*.html` (args forwarded
through to `-NoLaunch`), and must pass the ps1's nonzero exit code back
through on a missing file (`-NoDialog`, the ps1's other test-only switch,
keeps the friendly error dialog from blocking automated runs). It never
touches the registry and never launches a browser.

macOS / Linux: `python3 shared/test-generator.py` does the same for the
shared generator (`shared/curtopen-generator.py`) — the identical three
fixtures, the same escape invariant, plus a UTF-16LE-BOM decode check and a
real `parseCurt` round-trip through node when both node and the reference
`curt-format` package are available (skipped otherwise). Manual QA steps for
a real mac and a real Linux desktop are in `QA-CHECKLIST.md`.

### CI QA matrix

`.github/workflows/qa.yml` runs both Unix installers on real operating
systems (`macos-15`, `ubuntu-24.04`): syntax-gate every shell script, run
`mac/install.sh` / `linux/install.sh`, assert the registration (`duti -x
curt`, `plutil -lint`, mime glob tables + `xdg-mime query default`,
`desktop-file-validate`), exercise the open path against the committed
fixture `tests/fixtures/ci-sample.curt` — a spec-valid v1 envelope whose
message body smuggles `</script>` markup on purpose — and validate the
generated HTML with `tests/ci-validate.js` (escape invariant, JSON round
trip, offline-resource scan, real `parseCurt` through the vendored
reference implementation). It then attempts the real Launch Services
`open` / `xdg-open` paths (tolerated with `continue-on-error` — CI runners
are headless), uninstalls with residue assertions, and reinstalls to prove
idempotence. The Finder/DE eyeball lines of `QA-CHECKLIST.md` stay
human-only; everything automatable runs in CI. The workflow fires on push.


## Shipping

The whole folder is designed to zip as-is for a GitHub release (viewer +
scripts + this README; the only build step is `build.cmd`, and the shipped
`CurtViewer.exe` is reproducible from it on any Windows box). The zip's
`CurtViewer.exe` also makes the package winget-eligible (zip installer with
a portable nested exe); a draft manifest for `microsoft/winget-pkgs` lives
in `packaging/winget/` and is **not** submitted — submission is a human call
(see the README there).

## Part of the .curt suite

- [`curt-format`](https://github.com/JordanNewell/dot_curt) — the .curt format spec + reference implementation ([npm](https://www.npmjs.com/package/curt-format))
- [`curt-convert`](https://github.com/JordanNewell/curt-convert) — Claude Code transcripts → .curt ([npm](https://www.npmjs.com/package/curt-convert))
- [`curt-vcon`](https://github.com/JordanNewell/curt-vcon) — .curt ⇄ vCon (IETF) bridge ([npm](https://www.npmjs.com/package/curt-vcon))
- [`curt-wildchat`](https://github.com/JordanNewell/curt-wildchat) — WildChat-1M records → .curt ([npm](https://www.npmjs.com/package/curt-wildchat))
- [`curt-openwith`](https://github.com/JordanNewell/curt-openwith) — double-click any .curt file: offline viewer, Windows + macOS + Linux

MIT — see `LICENSE`.
