# QA checklist — macOS + Linux file association (curt-openwith)

The generator itself is covered by automated tests (`python3
shared/test-generator.py`, run on Windows during development). What cannot be
tested on a Windows box is the OS association layer — everything below is a
manual, one-time pass on a real machine. ~10 minutes per platform.

## Prep (both platforms)

- [ ] Extract the package folder somewhere stable.
- [ ] `python3 --version` works (macOS: `/usr/bin/python3 --version`; if it
      prompts for Command Line Tools, run `xcode-select --install` first).
- [ ] Have two test files ready: a real exported `.curt` file, and a
      deliberately corrupt one (rename a `.txt` with junk content to
      `bad.curt`).

## macOS

1. [ ] `cd` into the package folder; run `bash mac/install.sh`. Expect it to
       print `Built: /Users/<you>/Applications/Curt Viewer.app`, a
       "Registered with LaunchServices" line, and either the duti success
       line or the manual "Change All..." instructions.
2. [ ] `ls -R ~/Applications/Curt\ Viewer.app/Contents` shows
       `Info.plist`, `MacOS/curtopen`, and `Resources/viewer/` with
       `index.html`, `curt-format.js`, `style.css`, `fonts/`.
3. [ ] `plutil -lint ~/Applications/Curt\ Viewer.app/Contents/Info.plist`
       reports OK.
4. [ ] If duti was used: `duti -x curt` shows
       `com.dotcurt.curt-viewer`.
       If not: Finder → right-click a `.curt` → Get Info → Open with →
       "Curt Viewer" is offered → choose it → Change All...
5. [ ] Double-click the valid `.curt` in Finder. Expect: no bounce icon
       stuck, default browser opens a tab titled `<name> — Curt Viewer`
       rendering the conversation, and a `view-<name>.html` appears next to
       the `.curt` file.
6. [ ] Double-click `bad.curt`. Expect: a "Curt Viewer could not open this
       file" dialog (osascript) or the viewer's own error box — never a
       half-rendered transcript or a raw JSON dump.
7. [ ] Verify offline: disconnect from the network (Wi-Fi off), double-click
       the valid file. It must still render (fonts/styles are local; nothing
       fetches).
8. [ ] Open the generated `view-<name>.html` and check the browser's network
       inspector: zero remote requests.
9. [ ] Uninstall: `bash mac/uninstall.sh`. Expect the app gone from
       `~/Applications`, `duti -x curt` no longer showing
       `com.dotcurt.curt-viewer`, and your `.curt` files untouched.
10. [ ] Re-run `mac/install.sh` (reinstall) and confirm step 5 works again.
11. [ ] Optional: delete the extracted package folder, double-click the
        `.curt` — the app must still work (it carries its own copy of the
        viewer + generator).
12. [ ] Optional (multi-user hygiene): confirm nothing was written outside
        `~/Applications` and `~/Library` caches (no `/Library`, no sudo
        prompts during install).

## Linux

1. [ ] Run `sh linux/install.sh`. Expect "Installed:" listing
       `~/.local/share/curt-openwith`,
       `~/.local/share/applications/curt-viewer.desktop`, and
       `~/.local/share/mime/packages/x-curt.xml`, with no errors.
2. [ ] `grep Exec ~/.local/share/applications/curt-viewer.desktop` — the
       path points at `~/.local/share/curt-openwith/curtopen.sh` (correctly
       quoted if your home path contains spaces) and ends with `%f`.
3. [ ] `xdg-mime query default application/x-curt` → `curt-viewer.desktop`.
       `xdg-mime query filetype file.curt` → `application/x-curt` (GNOME:
       `gio info file.curt | grep standard::content-type`).
4. [ ] `desktop-file-validate ~/.local/share/applications/curt-viewer.desktop`
       (if desktop-file-utils installed) reports no errors.
5. [ ] Open the valid `.curt` by double-click in Nautilus/Dolphin, and once
       via `xdg-open <file>.curt`. Expect the default browser showing the
       rendered conversation, tab titled `<name> — Curt Viewer`, and
       `view-<name>.html` next to the source file.
6. [ ] Double-click `bad.curt`. Expect the viewer's error box (or a clean
       terminal error if launched from a shell) — no crash, no half render.
7. [ ] Verify offline: `xdg-open` the valid file with the network
       disconnected. Must render.
8. [ ] Check the browser network tab on the generated HTML: zero remote
       requests.
9. [ ] Uninstall: `sh linux/uninstall.sh`. Expect all three installed paths
       gone, `xdg-mime query default application/x-curt` no longer returning
       `curt-viewer.desktop`, and `view-*.html`/`.curt` files untouched.
10. [ ] Optional: repeat steps 1 and 5 on a second desktop environment
        (e.g. GNOME + KDE) — the mimeapps/desktop databases differ per DE.
11. [ ] Optional: home directory containing spaces — install and open a
        `.curt` from such a home to confirm the escaped `Exec=` line works.

## Pass criteria

A platform passes when: install is idempotent (re-run never fails), the
valid file opens rendered + offline with zero network requests, the corrupt
file produces a clean error, and uninstall leaves no handler residue and
touches no user files.
