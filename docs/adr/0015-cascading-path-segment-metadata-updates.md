# 15. Cascading Path Segment Metadata Updates

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

When a user modifies a path segment role or metadata property (such as Author, Universe, or Saga) for a directory containing multiple audiobooks, updating only a single book leaves sibling books in an inconsistent state.

## Decision Outcome

Chosen option:
1. **Dual Persistence**: Updates write directly to the parent `.metadata.json` file on disk (`author.metadata.json`, `universe.metadata.json`, or `saga.metadata.json`) AND perform an atomic bulk `UPDATE` in SQLite for all books matching the path prefix.
2. **Exact Relative Path Prefix Matching**: Segment sharing is determined strictly by exact directory path prefixes (e.g. `/root/Author/Saga/%`), preventing accidental cross-author folder collisions.
3. **Confirmation Preview**: When a change affects more than 1 book, display an explicit confirmation dialog listing the affected books before performing the batch update.

### Positive Consequences

* Guarantees metadata consistency across all books sharing a folder hierarchy.
* Preserves filesystem portability via updated `.metadata.json` files.
* Prevents accidental mass metadata corruption through explicit preview dialogs.
