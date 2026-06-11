# Roost

Roost is a native SwiftUI desktop catch-all that launches as a compact
always-on-top target, so you can paste, type, or drag URLs, file URLs, file
paths, and loose notes straight into the window — and an Agenda-style
notebook for organizing your thoughts by day and project, all stored locally.

## What works

### Capture
- Cute compact macOS catch-all window that can sit above the desktop.
- Separate Roost Library window opened from the main surface.
- Direct paste/type input in the main window.
- Drag-and-drop capture for browser links, file URLs, and text — every
  dropped item is captured, and repeat URLs are deduped.
- Paste-from-clipboard capture for copied links, file URLs, and text.
- Scored local sorting into smart buckets such as Important, Work, Code, Design,
  Money, Travel, Shopping, Media, People, Docs, Tools, and Read Later.
- Editable notes on every saved bookmark.

### Notes & projects (Agenda-style)
- Day-grouped notes timeline: every note lives on the day you wrote it, or a
  day you schedule it for.
- Projects to split notes across whatever you're juggling, with rename/delete
  and per-project colors.
- "On the Agenda" star for the handful of notes that matter right now, plus
  done/not-done checkmarks.
- Today view combining today's notes with (optionally) today's calendar events.
- Drop a link or file onto a note to attach it; attached items open from the
  note and also live in your collections.
- New Note from the toolbar, sidebar, or ⌘⇧N anywhere in the app.

### Local-first
- All data is JSON in Application Support — nothing leaves the Mac.
- Optional read-only calendar connection (EventKit) shows today's events
  beside your notes; connect it from the Today view or Settings. Roost never
  writes to your calendars.
- App Store prep files for icon, privacy manifest, sandbox entitlements
  (including calendars), and bundle metadata.
- Unified logging under subsystem `com.ivynbean.Roost`.

## Run

Use the project script:

```bash
./script/build_and_run.sh
```

The Codex Run action is wired to the same script.

## Test

Run the SwiftPM test suite:

```bash
swift test
```

## App Store Prep

Use the local packaging helper to stage and validate the app bundle:

```bash
./script/package_app_store.sh
```

Set `APP_SIGN_IDENTITY` to your Apple distribution signing identity when you are
ready to sign for distribution. See `docs/AppStoreChecklist.md` for the remaining
App Store Connect, signing, provisioning, and artwork-license steps.

## GitHub Downloads

For tester-friendly GitHub downloads, package a zipped app bundle:

```bash
./script/package_github_release.sh
```

That produces:

- `dist/Roost.app.zip`
- `dist/Roost.app.zip.sha256`

The repo also includes a GitHub Actions workflow at
`.github/workflows/release.yml`. Publishing a GitHub Release will build the app
on `macos-14` and attach the zip plus checksum automatically.

Unsigned builds are fine for internal testers, but other people will see
Gatekeeper warnings until the app is signed and notarized with your Apple
Developer credentials.

## Next model-backed step

`Sources/Roost/Services/BookmarkSorter.swift` is intentionally isolated so
the current local rules can be replaced or augmented by an AI classifier without
rewriting the UI or persistence layer.
