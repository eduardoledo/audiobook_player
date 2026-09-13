# Spec: Hierarchy Level Deduplication

Status: ready-for-agent

## Problem Statement

When path segments contain duplicate names across different hierarchy levels (e.g. `Author/Cosmere/Cosmere/BookTitle`), the library UI tree creates redundant nested subfolders with identical names.

## Solution

Update `PathMetadataParser` to inspect all parsed hierarchy levels (`author`, `universe`, `saga`, `era`, `bookTitle`). If a lower level matches a higher parent level (case-insensitive normalized match), set the lower level field to `null`. Update `AudiobookScanner` to auto-clear duplicated lower-level fields in SQLite on rescan.

## User Stories

1. As a listener browsing my library, I want duplicate folder names (e.g. `Cosmere` $\rightarrow$ `Cosmere`) merged into a single category node, so that I don't navigate through redundant subfolders.
2. As a user rescanning my library, I want existing SQLite database entries updated to clear duplicated lower-level columns.

## Implementation Decisions

- **Parser Level Deduplication**: `PathMetadataParser.parsePath` compares `universe`, `saga`, `era`, and `bookTitle` against parent level strings. Any lower-level match is set to `null`.
- **Database Cleanup on Rescan**: `AudiobookScanner` auto-clears duplicate lower-level properties in SQLite records during library rescans.
- **ADR Alignment**: Complies with ADR 0006, ADR 0018, and ADR 0019.

## Testing Decisions

- **Unit Testing at Parser Seam**: Assert in `test/services/path_metadata_parser_test.dart` that paths with duplicate segment names (e.g. `Author/Cosmere/Cosmere/BookTitle`) return `saga == null`.

## Out of Scope

- Renaming folders on the physical filesystem.

## Further Notes

- Guided by ADR 0019 ("Hierarchy Level Deduplication Policy").
- Enforces Zero Current Problems Quality Invariant (ADR 0014).
