# 18. Standalone Book Direct Author Node Placement

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Audiobooks without an explicit saga or universe subdivision (such as `Author/BookTitle`) were previously placed inside a redundant category node bearing the exact same name as the book title, resulting in awkward nested folder UX (e.g. `Author` $\rightarrow$ `BookTitle` $\rightarrow$ `BookTitle`).

## Decision Outcome

Chosen option:
1. **Null Saga/Universe Assignment**: 2-segment paths (`Author/BookTitle`) set `saga = null` and `universe = null` in `DirPathMetadata` and `Audiobook` models.
2. **Direct Author Node Placement**: In the library UI tree, standalone books (`saga == null`) render directly under their Author's expandable node alongside (and distinct from) Saga subfolders.
3. **Rescan Auto-Clearing**: Rescanning an existing library automatically sets `saga = null` and `universe = null` in SQLite for 2-segment standalone books, removing redundant dummy category records.

### Positive Consequences

* Eliminates redundant single-book folder wrappers in library navigation.
* Clean visual distinction between series/sagas and standalone novels.
* Cleans up legacy database records during library scans.
