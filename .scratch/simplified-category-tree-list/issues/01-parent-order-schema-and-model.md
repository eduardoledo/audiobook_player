# Issue 01: `parent_order` Schema & Model Migration

## Status

- [ ] Spec: [.scratch/simplified-category-tree-list/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/simplified-category-tree-list/spec.md)
- [ ] ADR: [docs/adr/0027-unified-category-ordering-parent-order.md](file:///home/eduardo/Development/audiobook_player/docs/adr/0027-unified-category-ordering-parent-order.md)

## Goal

Add `parent_order` field to SQLite `categories` schema, update `Audiobook` and `CategoryNode` models, and update `AudiobookScanner` to set `parentOrder`.

## Tasks

- [ ] Add `parent_order` column migration in `LibraryStorage` / SQLite schema.
- [ ] Update `CategoryNode` and `Audiobook` dart models with `parentOrder`.
- [ ] Update `AudiobookScanner` path parsing to populate `parentOrder`.
- [ ] Add unit tests verifying `parent_order` persistence and retrieval.
