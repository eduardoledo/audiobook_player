# 23. Nested Set UI Tree Rendering

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Previously, the directory tree view in `HomeScreen` rebuilt folder nodes in-memory by analyzing individual book file paths and string heuristics (`parseDirPath`), ignoring the stored database hierarchy. To ensure consistent library organization, the UI tree must be rendered directly from the SQLite `categories` Nested Set table.

## Decision Outcome

Chosen option:
1. **BLoC State Categories**: `HomeState` includes a `categories` list (`List<CategoryNode>`), loaded by `HomeCubit` from `LibraryStorage.getAllCategories()` or `getCategoriesSubtree()`.
2. **Nested Set UI Tree Construction**: `_buildDirectoryTree()` constructs the visual `_DirectoryNode` hierarchy directly from `CategoryNode.parentId`, `depth`, and `pathPrefix`, attaching books (`Audiobook` / `Ebook`) to their corresponding `CategoryNode` via `category_id`.
3. **Deterministic Tree Order**: Nodes are rendered ordered by `lft ASC`, preserving exact nested ordering and depth level formatting without dynamic string path re-parsing.

### Positive Consequences

* UI tree rendering strictly matches the persisted database category structure.
* Fast rendering without filesystem re-traversal or string regex parsing on every frame.
* Instant support for arbitrary category depth levels (Author -> Universe -> Saga -> Sub-series -> Era -> Book).
