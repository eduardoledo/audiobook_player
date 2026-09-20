# Issue 02: Refactor `_buildAudiobookList` with Author Virtual Level 0 & Nested Set Categories

## Status

- [ ] Spec: [.scratch/simplified-category-tree-list/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/simplified-category-tree-list/spec.md)
- [ ] ADR: [docs/adr/0027-unified-category-ordering-parent-order.md](file:///home/eduardo/Development/audiobook_player/docs/adr/0027-unified-category-ordering-parent-order.md)

## Goal

Simplify `_buildAudiobookList` in `home_screen.dart` to use `book.author` as virtual level 0 and render category subtrees directly from the SQLite Nested Set `CategoryNode` hierarchy. Completely remove legacy `_groupAudiobooks` and `universe`/`saga` UI wrappers.

## Tasks

- [ ] Remove `_groupAudiobooks` map grouping helper.
- [ ] Refactor `_buildAudiobookList` to construct author-level ExpansionTiles.
- [ ] Render author's uncategorized books (`categoryId == null`) at the top of that author's tile.
- [ ] Recursively render `CategoryNode` subtrees beneath the author's uncategorized books, sorted by `parentOrder` then title.
- [ ] Render a single fallback "Sin categoría" ExpansionTile at the bottom of the list for books with no assigned author (`author == 'Unknown'`).
- [ ] Update widget tests in `test/widgets/nested_set_ui_tree_test.dart` to assert author virtual level 0 and category subtrees.
