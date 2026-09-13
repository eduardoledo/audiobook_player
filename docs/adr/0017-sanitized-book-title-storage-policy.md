# 17. Sanitized Book Title Storage Policy

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Titles extracted from audio files or directory names often contain bracketed publication years (e.g. `(2006)`) or parenthetical narrator markers (e.g. `(read by Frank Muller)`). If saved raw into SQLite, these extra tokens produce cluttered and redundant title displays in player and library views.

## Decision Outcome

Chosen option:
1. **Universal Scanner Sanitization**: `AudiobookScanner` strips publication year and narrator tokens from `bookTitle` before instantiating `Audiobook` models and saving records to SQLite.
2. **Preservation of Explicit JSON Overrides**: Explicit `"title"` fields in local `book.metadata.json` files are preserved verbatim as intentional user overrides.
3. **Rescan Auto-Sanitization**: Rescanning an existing library automatically updates existing SQLite database rows to sanitize titles whenever a year or narrator marker is recognized.

### Positive Consequences

* Clean, concise title displays in all UI widgets.
* Separates metadata fields (`publishYear`, `narrator`) from clean display titles (`bookTitle`).
* Automatically cleans up dirty historical library records during library rescans.
