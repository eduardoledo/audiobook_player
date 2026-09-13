# Spec: Sanitized Book Title Storage

Status: ready-for-agent

## Problem Statement

Book titles extracted during directory scanning frequently include raw publication year brackets (e.g. `[2006]`) or narrator markers (e.g. `(read by Frank Muller)`), causing cluttered title labels in player UI views.

## Solution

Ensure `AudiobookScanner` strips all detected publication year and narrator tokens from `bookTitle` prior to instantiating `Audiobook` models and writing SQLite entries, while preserving explicit titles defined in `book.metadata.json`. Rescanning an existing library automatically updates existing SQLite database entries to sanitize dirty title records.

## User Stories

1. As an audiobook listener, I want titles displayed cleanly without bracketed years or narrator text, so that the player UI displays clean book titles.
2. As a user with custom `book.metadata.json` files, I want my explicitly defined JSON titles preserved verbatim.
3. As a user rescanning my library, I want existing dirty titles in SQLite automatically cleaned without needing to re-import the library.

## Implementation Decisions

- **Scanner Sanitization**: Apply `stripPublishYearFromTitle` and `stripNarratorFromTitle` inside `AudiobookScanner` for all scanned titles.
- **Explicit Override Exemption**: Preserves exact `title` strings provided in `book.metadata.json`.
- **Database Rescan Sanitization**: Library rescans sanitize and update stored SQLite entries for existing audiobooks.
- **ADR Alignment**: Complies with ADR 0016 and ADR 0017.

## Testing Decisions

- **Unit Testing at Scanner Seam**: Assert in `test/audiobook_scanner_test.dart` that titles containing year and narrator brackets are sanitized before being assigned to `Audiobook.title`.

## Out of Scope

- Modifying directory names on the filesystem.

## Further Notes

- Guided by ADR 0017 ("Sanitized Book Title Storage Policy").
- Enforces Zero Current Problems Quality Invariant (ADR 0014).
