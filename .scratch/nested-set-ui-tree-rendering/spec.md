# Spec: Nested Set UI Tree Rendering

Status: ready-for-agent

## Problem Statement

Currently, `HomeScreen` constructs its directory view by dynamically parsing book directory paths using heuristics (`parseDirPath`) on every build cycle. This ignores the persisted SQLite `categories` Nested Set table and causes visual inconsistencies when books belong to custom or deeply nested category structures.

## Solution

Refactor `HomeScreen` directory tree construction to build visual nodes directly from `CategoryNode` records stored in SQLite (`categories` table) and loaded via `HomeState`. Audiobooks and ebooks will attach to their corresponding category node in the tree using their `category_id`.

## User Stories

1. As an audiobook listener, I want the library folder view to display category nodes in the exact order and depth defined in the database Nested Set tree (`lft ASC`), so that multi-level series (Author -> Universe -> Saga -> Era) render reliably.
2. As a user, I want books attached to intermediate category nodes (e.g. directly under an Author) to display alongside sub-category folders without dummy category wrappers.
3. As a developer, I want `HomeScreen` to build its visual tree without re-parsing filesystem path strings or executing regular expressions on every frame, improving UI performance.

## Implementation Decisions

- **LibraryStorage Categories Query**: Add `getAllCategories()` to `LibraryStorage`, executing `SELECT * FROM categories ORDER BY lft ASC`.
- **BLoC State Integration**: Add `categories` field (`List<CategoryNode>`) to `HomeState`. `HomeCubit` will query and emit `categories` during `loadData()`, `scanDirectory()`, and `rescanAll()`.
- **UI Tree Construction**: Refactor `_buildDirectoryTree()` in `HomeScreen` to build `_DirectoryNode` instances using `CategoryNode.parentId` and `lft` sequence, attaching books matching `book.categoryId == category.id`.
- **Architectural Seam**: `HomeCubit` and `HomeScreen` UI tree rendering (`_buildDirectoryTree`).

## Testing Decisions

- **UI Seam Testing**: Test `_buildDirectoryTree` or widget tree output with mocked `HomeState` containing pre-populated `categories` and `audiobooks` with `category_id`.
- **Ordering Verification**: Verify that category nodes render in strict `lft ASC` order and depth levels indent accurately.
- **Prior Art**: Follow existing widget test patterns in `test/home_search_bar_test.dart`.

## Out of Scope

- Drag-and-drop manual reordering of UI tree nodes in this ticket.

## Further Notes

- Documented in [ADR 0023](file:///home/eduardo/Development/audiobook_player/docs/adr/0023-nested-set-ui-tree-rendering.md) and [CONTEXT.md](file:///home/eduardo/Development/audiobook_player/CONTEXT.md#L134).
