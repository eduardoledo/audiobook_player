# Ticket 02: Nested Set Tree Recalculation & Subtree Query Operations

Status: resolved
Type: task
Blocked by: 01

## Description

Implement Depth-First Search (DFS) tree recalculation and single-query subtree retrieval methods in `LibraryStorage`.

## Requirements

1. Add `rebuildNestedSet()` method to `LibraryStorage`:
   - Traverse categories by parent-child relationships and update `lft`, `rgt`, and `depth` values sequentially in an atomic transaction.
   - Enforce invariant: `lft < rgt` and `rgt - lft = 2 * (number of descendants) + 1`.
2. Add `getCategoriesSubtree(int rootId)` to `LibraryStorage`:
   - Execute query: `SELECT * FROM categories WHERE lft BETWEEN ? AND ? ORDER BY lft ASC`.
3. Add `insertCategory(CategoryNode node)` to `LibraryStorage`:
   - Insert category node and invoke `rebuildNestedSet()`.

## Verification

- Create unit test `test/services/nested_set_category_test.dart` verifying DFS boundary assignments and subtree queries.
- `flutter test test/services/nested_set_category_test.dart` passes.
- `flutter analyze lib/ test/` passes with 0 errors and 0 warnings.
