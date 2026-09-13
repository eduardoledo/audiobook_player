# Spec: Nested Set Category Hierarchy & Multi-Depth Book Placement

Status: ready-for-agent

## Problem Statement

The audiobook library currently organizes audiobooks and ebooks into fixed category levels (Author -> Universe -> Saga -> Book). This rigid structure fails to accommodate deep or non-standard directory layouts (e.g. Cosmere -> Mistborn -> Era 1 -> Secret History), multi-tier sub-series, or standalone books that exist directly under an Author without dummy Saga/Universe containers. Querying hierarchical subtrees recursively in SQLite is inefficient without a dedicated hierarchy model.

## Solution

Implement the **Nested Set Model** (`lft`, `rgt`, `depth`, `parent_id`, `path_prefix`) in a dedicated SQLite `categories` table. This allows arbitrary nesting depth for category nodes (Author, Universe, Saga, Sub-series, Era) and enables single-query subtree retrieval using `WHERE lft BETWEEN parent.lft AND parent.rgt`. 

Additionally, allow any `Audiobook` or `Ebook` to store a `category_id` referencing a node at any level of depth in the category tree. `AudiobookScanner` will dynamically generate and update the `categories` tree during directory scanning, triggering user confirmation prompts if path structural ambiguities occur.

## User Stories

1. As an audiobook listener with complex series collections, I want my library to reflect multi-level folder hierarchies (such as Author -> Universe -> Saga -> Era), so that I can browse my audiobooks in their exact narrative structure.
2. As a user with standalone audiobooks, I want standalone books to attach directly under an Author category node without forcing empty or dummy category sub-folders.
3. As a developer, I want to retrieve an entire category subtree and all its nested sub-categories in a single SQL query using `WHERE lft BETWEEN parent.lft AND parent.rgt`, so that library UI tree rendering is fast and performant.
4. As a user scanning a new folder directory, I want `AudiobookScanner` to automatically build the `categories` Nested Set tree based on directory paths, so that I don't have to manually create category nodes.
5. As a user with custom folder structures, I want to be prompted when `AudiobookScanner` encounters ambiguous category levels, so that I can resolve path mapping conflicts before metadata is saved.
6. As a library manager, I want changes made to a parent category node to cascade to all descendant category nodes and linked audiobooks, so that metadata remains synchronized across the filesystem and database.

## Implementation Decisions

- **Nested Set Table Schema**: Create SQLite table `categories` with columns:
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`
  - `name TEXT NOT NULL`
  - `lft INTEGER NOT NULL`
  - `rgt INTEGER NOT NULL`
  - `depth INTEGER NOT NULL`
  - `parent_id INTEGER`
  - `path_prefix TEXT UNIQUE`
- **Book-to-Category Association**: Add nullable `category_id INTEGER` to `audiobooks` and `ebooks` SQLite tables and Dart models (`Audiobook`, `Ebook`), establishing a foreign key relationship to `categories(id)`.
- **Nested Set Tree Recalculation**: Implement `rebuildNestedSet()` in `LibraryStorage` using Depth-First Search (DFS) to assign sequential `lft` and `rgt` boundaries and `depth` counters whenever categories are inserted, moved, or deleted.
- **Scanner Tree Building**: Update `AudiobookScanner` to insert/resolve `CategoryNode` entries per directory path segment relative to the scan root, linking books to the leaf (or intermediate) category ID.
- **Architectural Seam**: `LibraryStorage` serves as the primary seam for category tree querying (`getCategoriesSubtree(int rootId)`), Nested Set recalculations, and book `category_id` updates.

## Testing Decisions

- **External Behavior Testing**: Test category tree operations through `LibraryStorage` public API without inspecting internal SQL execution steps.
- **Nested Set Invariants**: Test that for any category node, `lft < rgt` and `rgt - lft = 2 * (number of descendants) + 1`.
- **Subtree Queries**: Verify that querying `WHERE lft BETWEEN parent.lft AND parent.rgt` returns all descendants at all depths in correct tree order.
- **Prior Art**: Follow existing test patterns in `test/services/path_metadata_parser_test.dart` and `test/cascading_metadata_update_test.dart`.

## Out of Scope

- Drag-and-drop manual UI reordering of Nested Set nodes (categories will be ordered by `lft` / alphabetical / reading order keys).
- Web-based category cloud sync (local SQLite persistence only).

## Further Notes

- Documented in [ADR 0022](file:///home/eduardo/Development/audiobook_player/docs/adr/0022-nested-set-category-hierarchy.md) and [CONTEXT.md](file:///home/eduardo/Development/audiobook_player/CONTEXT.md#L128).
