# Spec: Standalone Book Direct Author Node Placement

Status: ready-for-agent

## Problem Statement

Standalone audiobooks (paths structured as `Author/BookTitle`) were previously assigned `saga = bookTitle` or placed inside a dummy category matching their title, producing redundant nested category nodes in the library tree (`Author` $\rightarrow$ `BookTitle` $\rightarrow$ `BookTitle`).

## Solution

Ensure `PathMetadataParser` and `AudiobookScanner` assign `saga = null` and `universe = null` for 2-segment standalone paths (`Author/BookTitle`). Update library UI tree building to place `saga == null` audiobooks directly under the Author's expandable node. Rescanning an existing library automatically updates existing SQLite database entries to clear `saga` and `universe` for 2-segment standalone books.

## User Stories

1. As a listener browsing my library, I want standalone books without a saga to appear directly under the Author node, so that I don't have to open a redundant folder with the exact same name as the book.
2. As a user rescanning my library, I want legacy database entries for standalone books updated to `saga = null`, so that old dummy categories disappear automatically.

## Implementation Decisions

- **Null Saga/Universe Assignment**: 2-segment relative paths (`Author/BookTitle`) assign `saga = null` and `universe = null` in `DirPathMetadata` and `Audiobook` models.
- **Direct UI Node Rendering**: Library tree widgets place books with `saga == null` directly under the Author parent node.
- **Database Rescan Clearing**: Library rescans set `saga = null` and `universe = null` in SQLite for 2-segment standalone books.
- **ADR Alignment**: Complies with ADR 0006 and ADR 0018.

## Testing Decisions

- **Unit Testing at Parser and Scanner Seam**: Assert in `test/services/path_metadata_parser_test.dart` and `test/audiobook_scanner_test.dart` that 2-segment paths yield `saga == null` and `universe == null`.

## Out of Scope

- Moving files on the filesystem.

## Further Notes

- Guided by ADR 0018 ("Standalone Book Direct Author Node Placement").
- Enforces Zero Current Problems Quality Invariant (ADR 0014).
