# winget manifest DRAFT — JordanNewell.CurtViewer 1.0.1

**Status: draft, NOT submitted.** No PR exists or should be filed until a
human says go. Everything below is the checklist for that day.

## What's here

The three schema-1.9 manifest files winget-pkgs expects, validated locally
with `winget validate` (passes on winget 1.29.380):

| file | manifest type |
|------|---------------|
| `JordanNewell.CurtViewer.yaml` | version |
| `JordanNewell.CurtViewer.installer.yaml` | installer (zip → portable CurtViewer.exe) |
| `JordanNewell.CurtViewer.locale.en-US.yaml` | defaultLocale (en-US) |

Installer URL points at the v1.0.1 release zip;
`InstallerSha256` is the sha256 of that exact zip — **it must be recomputed
if the zip is ever rebuilt**, winget rejects a mismatch and the bot closes
the PR for it.

## PR-readiness checklist (human)

1. Confirm identity/package name: `JordanNewell.CurtViewer` is taken from
   the GitHub account — winget-pkgs requires the publisher segment to match
   the account that owns the installer URL, and a maintainer may ask you to
   verify ownership (they do this via a comment template on the PR; the
   first submission is checked manually).
2. Sign the Microsoft CLA (the winget-pkgs PR will block on it otherwise):
   https://cla.opensource.microsoft.com — sign with the account/email you
   open the PR from.
3. Fork https://github.com/microsoft/winget-pkgs, add the three files under
   `manifests/j/JordanNewell/CurtViewer/1.0.1/` (folder layout mirrors the
   identifier), commit, open a PR against `master`. PR title convention:
   the bot wants the `New package: JordanNewell.CurtViewer version 1.0.1`
   style (it usually generates this if the manifest is added via PR).
4. The winget-validated-bot checks the manifest, the URL, and the hash —
   the release zip must already be public when the PR opens (it is).
5. `wingetcreate` alternative: `wingetcreate new
   <zip-url> --version 1.0.1` can regenerate these files; submitting with
   `wingetcreate submit` needs a GitHub token with the repo scope. The
   hand-written manifests here already validate, so this is optional.
6. After merge, `winget install JordanNewell.CurtViewer` serves the
   portable exe. The double-click `.curt` association remains a separate,
   explicit `install.cmd` step by design.
