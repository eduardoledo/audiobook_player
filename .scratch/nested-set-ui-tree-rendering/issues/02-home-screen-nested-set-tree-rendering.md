# Ticket 02: Refactor HomeScreen Directory Tree to Render from Nested Set Categories

Status: resolved
Type: task
Blocked by: 01

## Description

Refactor `_buildDirectoryTree()` in `HomeScreen` to build visual `_DirectoryNode` instances using `state.categories` and `category_id` from audiobooks/ebooks.

## Requirements

1. Update `_buildDirectoryTree()` in `lib/screens/home_screen.dart`:
   - Map each `CategoryNode` in `state.categories` into a visual tree node using `parentId` relationships.
   - Attach audiobooks/ebooks matching `book.categoryId == category.id` directly to that node.
   - Fallback: Any book without a `categoryId` attaches to a root or fallback folder based on path.
2. Maintain UI formatting, depth indentation, and expansion states.

## Verification

- Create unit/widget test in `test/widgets/nested_set_ui_tree_test.dart` verifying correct tree node rendering from `CategoryNode` list.
- `flutter analyze lib/ test/` passes with 0 errors and 0 warnings.
- `flutter test` passes.
