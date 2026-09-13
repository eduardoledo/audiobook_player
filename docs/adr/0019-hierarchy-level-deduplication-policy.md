# 19. Hierarchy Level Deduplication Policy

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

When directory structures or metadata files contain duplicate names across different hierarchy levels (e.g. `Author/Cosmere/Cosmere/BookTitle` or `Saga/Era 1/Era 1`), the library tree was rendering redundant nested subfolders with identical names.

## Decision Outcome

Chosen option:
1. **Parser Level Deduplication**: `PathMetadataParser` inspects all hierarchy levels (`author`, `universe`, `saga`, `era`, `bookTitle`). If a lower level matches a higher parent level (case-insensitive normalized string match), the lower level field is set to `null`.
2. **Multi-Level Cascade**: Deduplication checks occur across all adjacent and non-adjacent parent levels (e.g. `saga` cleared if matching `universe` or `author`; `era` cleared if matching `saga`, `universe`, or `author`).
3. **Rescan Database Cleanup**: Library rescans automatically set duplicated lower-level columns to `null` in SQLite.

### Positive Consequences

* Eliminates redundant duplicate subfolder nodes in the library tree UI.
* Keeps directory path parsing strictly deduplicated without visual clutter.
* Cleans up historical database rows during library rescans.
