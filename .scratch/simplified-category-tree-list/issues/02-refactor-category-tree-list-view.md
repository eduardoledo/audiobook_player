# Issue 02: Refactor `_buildAudiobookList` with Collapsible Category Tree

## Status

- [ ] Spec: [.scratch/simplified-category-tree-list/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/simplified-category-tree-list/spec.md)
- [ ] ADR: [docs/adr/0027-unified-category-ordering-parent-order.md](file:///home/eduardo/Development/audiobook_player/docs/adr/0027-unified-category-ordering-parent-order.md)

## Goal

Simplify `_buildAudiobookList` in `home_screen.dart` to use the Nested Set category tree exclusively, remove legacy `_groupAudiobooks`, and append a "Sin categoría" fallback category for uncategorized audiobooks.

## Tasks

- [ ] Remove `_groupAudiobooks` map grouping helper.
- [ ] Update `_buildAudiobookList` to construct tree tiles directly from `CategoryNode` hierarchy sorted by `parent_order`.
- [ ] Add explicit "Sin categoría" root category tile at the bottom of the tree for audiobooks with `categoryId == null`.
- [ ] Update widget tests for `HomeScreen` library view.
