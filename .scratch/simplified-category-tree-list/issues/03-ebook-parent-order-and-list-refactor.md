# Issue 03: `Ebook.parentOrder` Model & `_buildEbookList` Refactoring

## Status

- [ ] Spec: [.scratch/simplified-category-tree-list/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/simplified-category-tree-list/spec.md)
- [ ] ADR: [docs/adr/0027-unified-category-ordering-parent-order.md](file:///home/eduardo/Development/audiobook_player/docs/adr/0027-unified-category-ordering-parent-order.md)

## Goal

Add `parentOrder` property to `Ebook` model and refactor `_buildEbookList` in `home_screen.dart` to use virtual author level 0 and Nested Set category subtrees.

## Tasks

- [ ] Add `parentOrder` (`double?`) field to `Ebook` model, constructor, `fromJson`, `toJson`, and `copyWith`.
- [ ] Refactor `_buildEbookList` to render author level 0 tiles, author uncategorized ebooks, and recursive `CategoryNode` subtrees.
- [ ] Add single "Sin categoría" fallback ExpansionTile at the bottom for ebooks without an author (`author == 'Unknown'`).
- [ ] Add unit tests for `Ebook.parentOrder` model serialization and widget test for `_buildEbookList`.
