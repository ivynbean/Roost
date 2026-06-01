# BucketDesk

BucketDesk is a native macOS SwiftUI prototype for a floating desktop catch-all
bucket. It launches as a compact always-on-top target, so you can paste, type, or
drag URLs, file URLs, file paths, and loose notes straight into the bucket.

## What works

- Compact floating macOS drop bucket that can sit above the desktop.
- Separate bookmark library window opened from the bucket.
- Direct paste/type input in the bucket window.
- Drag-and-drop capture for browser links, file URLs, and text.
- Paste-from-clipboard capture for copied links, file URLs, and text.
- Manual paste/add capture for URLs, paths, and notes.
- Scored local sorting into smart buckets such as Important, Work, Code, Design,
  Money, Travel, Shopping, Media, People, Docs, Tools, and Read Later.
- JSON persistence in Application Support.
- Toolbar, sidebar, search, detail view, context menu moves, and open actions.
- Unified logging under subsystem `com.codex.BucketDesk`.

## Run

Use the project script:

```bash
./script/build_and_run.sh
```

The Codex Run action is wired to the same script.

## Next model-backed step

`Sources/BucketDesk/Services/BookmarkSorter.swift` is intentionally isolated so
the current local rules can be replaced or augmented by an AI classifier without
rewriting the UI or persistence layer.
