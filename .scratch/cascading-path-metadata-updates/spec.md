# Spec: Cascading Path Segment Metadata Updates

Status: ready-for-agent

## Problem Statement

When a user edits path segment roles or metadata properties (such as Author, Universe, or Saga) for a directory containing multiple audiobooks, only a single book entry was updated in isolation. This left sibling books under the same directory in an inconsistent state and required manual edits book by book.

## Solution

Implement an automated cascading update mechanism. When a user updates metadata or segment mapping for a path segment, the application propagates the change to all books sharing that exact directory path prefix, updating both local `.metadata.json` files on disk and SQLite library database records. A confirmation dialog previews the list of affected books whenever more than one book will be modified.

## User Stories

1. As an audiobook listener, I want path metadata edits to automatically apply to all books in the same directory branch, so that I don't have to edit sibling books individually.
2. As a user organizing a large series, I want a preview dialog listing all affected books before a batch path update executes, so that I can confirm which books will be modified.
3. As a user moving files between devices, I want shared folder metadata written to `.metadata.json` on disk, so that my library organization remains portable across storage locations.
4. As a library manager, I want path segment updates to use exact directory path prefixes, so that books in unrelated folders with identical names are not accidentally overwritten.

## Implementation Decisions

- **Dual Persistence Strategy**: Updates write to the parent directory's `.metadata.json` (`author.metadata.json`, `universe.metadata.json`, or `saga.metadata.json`) AND perform a bulk `UPDATE` in SQLite for all books matching the path prefix.
- **Exact Path Prefix Matching**: Segment matching uses exact relative directory path prefixes (e.g. `/root/Author/Saga/%`), avoiding false positives across different authors.
- **Batch Confirmation Dialog**: If a segment edit affects more than 1 book, present an explicit confirmation modal previewing the target count and list of affected titles before execution.
- **Domain Alignment**: Uses `PathMetadataParser` and `LibraryStorage` abstractions according to ADR 0006 and ADR 0015.

## Testing Decisions

- **Unit Testing at Service Seam**: Verify batch path updates by asserting that `LibraryStorage` updates both `.metadata.json` on disk and SQLite table rows for matching path prefixes.
- **Isolation**: Test prefix matching to ensure sibling directories are updated while non-matching directory trees remain untouched.
- **Prior Art**: Follows patterns established in `test/services/path_metadata_parser_test.dart` and `test/hierarchical_metadata_test.dart`.

## Out of Scope

- Remote cloud metadata syncing or third-party web scraping during local path updates.
- Automated physical folder renaming on the device filesystem.

## Further Notes

- Guided by ADR 0015 ("Cascading Path Segment Metadata Updates").
- Enforces the Zero Current Problems Quality Invariant (ADR 0014).
