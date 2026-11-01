# QA checklist — macOS + Linux file association (curt-openwith)

The generator itself is covered by automated tests (`python3
shared/test-generator.py`, run on Windows during development). What cannot be
tested on a Windows box is the OS association layer — that part now runs in
CI: `.github/workflows/qa.yml` executes both installers on real runners
(macos-15, ubuntu-24.04) — install, registration assertions, the open path
against `tests/fixtures/ci-sample.curt` (validated by `tests/ci-validate.js`
through the vendored reference `parseCurt`), uninstall residue, and
idempotent reinstall. Items tagged **[CI]** are covered there; **[HUMAN]**
items need eyes or hardware (Finder dialogs, DE double-click, browser
inspectors). The checklist remains the ~10-minute manual pass for anything
not automated.

Coverage tags: **[CI]** automated in qa.yml · **[HUMAN]** manual only ·
**[CI+HUMAN]** CI covers the mechanical half, humans the rendered eyeball.

## Prep (both platforms)

- [ ] Extract the package folder somewhere stable. **[HUMAN]**
- [ ] `python3 --version` works (macOS: `/usr/bin/python3 --version`; if it
      prompts for Command Line Tools, run `xcode-select --install` first).
      **[CI]** (both runners)
- [ ] Have two test files ready: a real exported `.curt` file, and a
      deliberately corrupt one (rename a `.txt` with junk content to
      `bad.curt`). **[CI]** (valid fixture committed at
      `tests/fixtures/ci-sample.curt` — with smuggled `</script>` content;
      corrupt-input rejection is checked directly against `parseCurt`)

## macOS

1. [ ] `cd` into the package folder; run `bash mac/install.sh`. Expect it to
       print `Built: /Users/<you>/Applications/Curt Viewer.app`, a
       "Registered with LaunchServices" line, and either the duti success
       line or the manual "Change All..." instructions. **[CI]**
2. [ ] `ls -R ~/Applications/Curt\ Viewer.app/Contents` shows
       `Info.plist`, `MacOS/curtopen`, and `Resources/viewer/` with
       `index.html`, `curt-format.js`, `style.css`, `fonts/`. **[CI]** (key
       files asserted directly)
3. [ ] `plutil -lint ~/Applications/Curt\ Viewer.app/Contents/Info.plist`
       reports OK. **[CI]**
4. [ ] If duti was used: `duti -x curt` shows
       `com.dotcurt.curt-viewer`. **[CI]** (CI brew-installs duti)
       If not: Finder → right-click a `.curt` → Get Info → Open with →
       "Curt Viewer" is offered → choose it → Change All... **[HUMAN]**
5. [ ] Double-click the valid `.curt` in Finder. Expect: no bounce icon
       stuck, default browser opens a tab titled `<name> — Curt Viewer`
       rendering the conversation, and a `view-<name>.html` appears next to
       the `.curt` file. **[CI+HUMAN]** (CI runs the wrapper open path + the
       real `open` LaunchServices path — continue-on-error for headless
       flake — and validates the generated html incl. the title swap; the
       rendered-tab eyeball stays human)
6. [ ] Double-click `bad.curt`. Expect: a "Curt Viewer could not open this
       file" dialog (osascript) or the viewer's own error box — never a
       half-rendered transcript or a raw JSON dump. **[CI+HUMAN]** (CI proves
       `parseCurt` rejects corrupt input null-clean; the dialog appearance
       stays human)
7. [ ] Verify offline: disconnect from the network (Wi-Fi off), double-click
       the valid file. It must still render (fonts/styles are local; nothing
       fetches). **[CI+HUMAN]** (CI statically asserts no remote `src=` /
       `url()` references; a true air-gapped render stays human)
8. [ ] Open the generated `view-<name>.html` and check the browser's network
       inspector: zero remote requests. **[CI+HUMAN]** (same static scan as
       line 7; the inspector pass stays human)
9. [ ] Uninstall: `bash mac/uninstall.sh`. Expect the app gone from
       `~/Applications`, `duti -x curt` no longer showing
       `com.dotcurt.curt-viewer`, and your `.curt` files untouched.
       **[CI]** (app-gone asserted; LS's stale `duti -x` cache is allowed to
       linger, so CI doesn't hard-fail on that half)
10. [ ] Re-run `mac/install.sh` (reinstall) and confirm step 5 works again.
        **[CI]** (reinstall + `plutil` + `duti -x` re-asserted; re-open eyeball human)
11. [ ] Optional: delete the extracted package folder, double-click the
        `.curt` — the app must still work (it carries its own copy of the
        viewer + generator). **[HUMAN]** (CI's `open` step already exercises
        the self-contained bundle, but the deleted-folder scenario stays human)
12. [ ] Optional (multi-user hygiene): confirm nothing was written outside
        `~/Applications` and `~/Library` caches (no `/Library`, no sudo
        prompts during install). **[HUMAN]**

## Linux

1. [ ] Run `sh linux/install.sh`. Expect "Installed:" listing
       `~/.local/share/curt-openwith`,
       `~/.local/share/applications/curt-viewer.desktop`, and
       `~/.local/share/mime/packages/x-curt.xml`, with no errors. **[CI]**
2. [ ] `grep Exec ~/.local/share/applications/curt-viewer.desktop` — the
       path points at `~/.local/share/curt-openwith/curtopen.sh` (correctly
       quoted if your home path contains spaces) and ends with `%f`.
       **[CI]** (Exec line asserted incl. trailing `%f`; spaces-in-home
       quoting stays human)
3. [ ] `xdg-mime query default application/x-curt` → `curt-viewer.desktop`.
       `xdg-mime query filetype file.curt` → `application/x-curt` (GNOME:
       `gio info file.curt | grep standard::content-type`). **[CI]** (both
       xdg-mime queries; `gio` per-DE variant stays human)
4. [ ] `desktop-file-validate ~/.local/share/applications/curt-viewer.desktop`
       (if desktop-file-utils installed) reports no errors. **[CI]**
5. [ ] Open the valid `.curt` by double-click in Nautilus/Dolphin, and once
       via `xdg-open <file>.curt`. Expect the default browser showing the
       rendered conversation, tab titled `<name> — Curt Viewer`, and
       `view-<name>.html` next to the source file. **[CI+HUMAN]** (CI runs
       `curtopen.sh` — the generator + html-validation half; `xdg-open` has
       no browser headless so the real launch is continue-on-error; the
       rendered-tab eyeball stays human)
6. [ ] Double-click `bad.curt`. Expect the viewer's error box (or a clean
       terminal error if launched from a shell) — no crash, no half render.
       **[CI+HUMAN]** (parser null-rejection covered; the box eyeball human)
7. [ ] Verify offline: `xdg-open` the valid file with the network
       disconnected. Must render. **[CI+HUMAN]** (static no-remote-resources
       scan; air-gapped render human)
8. [ ] Check the browser network tab on the generated HTML: zero remote
       requests. **[CI+HUMAN]** (same static scan; inspector pass human)
9. [ ] Uninstall: `sh linux/uninstall.sh`. Expect all three installed paths
       gone, `xdg-mime query default application/x-curt` no longer returning
       `curt-viewer.desktop`, and `view-*.html`/`.curt` files untouched.
       **[CI]** (paths gone + mimeapps default line removed asserted)
10. [ ] Optional: repeat steps 1 and 5 on a second desktop environment
        (e.g. GNOME + KDE) — the mimeapps/desktop databases differ per DE.
        **[HUMAN]**
11. [ ] Optional: home directory containing spaces — install and open a
        `.curt` from such a home to confirm the escaped `Exec=` line works.
        **[CI+HUMAN]** (CI runs the fixture from a directory with spaces;
        a spaces-in-HOME install stays human)

## Pass criteria

CI passes on the [CI] items above. A platform passes overall when: install is
idempotent (re-run never fails), the
valid file opens rendered + offline with zero network requests, the corrupt
file produces a clean error, and uninstall leaves no handler residue and
touches no user files.
