# Issue 04: `PathSegmentRole` Enum Update & `PathStructureSelectorDialog` Adaptation

## Status

- [ ] Spec: [.scratch/simplified-category-tree-list/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/simplified-category-tree-list/spec.md)
- [ ] ADR: [docs/adr/0027-unified-category-ordering-parent-order.md](file:///home/eduardo/Development/audiobook_player/docs/adr/0027-unified-category-ordering-parent-order.md)

## Goal

Update `PathSegmentRole` to replace obsolete roles (`universe`, `saga`, `era`) with a unified `category` role ("Categoría / Subcategoría"), adapt `PathStructureSelectorDialog`, and add automatic SQLite migration for saved pattern rules in `LibraryStorage`.

## Tasks

- [ ] Update `PathSegmentRole` enum in `lib/models/path_pattern_rule.dart`: replace `universe`, `saga`, `era` with `category` ("Categoría / Subcategoría").
- [ ] Update `LibraryStorage` rule deserialization/migration to automatically convert saved strings `'universe'`, `'saga'`, `'era'` to `'category'`.
- [ ] Update default heuristic in `PathStructureSelectorDialog` to assign `PathSegmentRole.category` for intermediate segments.
- [ ] Update scanner and conflict validator logic in `AudiobookScanner` and `LibraryStorage` to handle `PathSegmentRole.category`.
- [ ] Update unit and widget tests in `test/widgets/path_structure_selector_dialog_test.dart` and `test/services/path_pattern_conflict_test.dart`.
