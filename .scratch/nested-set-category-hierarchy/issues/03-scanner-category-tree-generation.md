# Ticket 03: Scanner Category Tree Generation & Multi-Depth Book Assignment

Status: resolved
Type: task
Blocked by: 01, 02

## Description

Integrate `AudiobookScanner` with `LibraryStorage` to dynamically build `categories` Nested Set nodes during directory scanning and link audiobooks to their category ID at any level of depth.

## Requirements

1. Update `AudiobookScanner`:
   - For each scanned book path relative to the scan root, extract path segments and resolve/create corresponding category nodes in the `categories` Nested Set table via `LibraryStorage`.
   - Assign `category_id` to each scanned `Audiobook` pointing to the leaf (or intermediate parent) category node.
2. Handle Ambiguity Resolution:
   - If path structure conflicts or ambiguous segment mapping rules are detected during scanning, surface a confirmation callback to prompt the user.

## Verification

- Run full scanner test with mock directory hierarchy.
- `flutter test` passes.
- `flutter analyze lib/ test/` passes with 0 errors and 0 warnings.
