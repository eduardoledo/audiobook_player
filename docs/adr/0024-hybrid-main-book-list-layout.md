# 24. Hybrid Main Book List Layout & Multi-Level List Accordion (Nested Set Binding & SQLite View Persistence)

Date: 2026-09-17

## Status

Accepted

## Context

Users require flexibility when browsing their audiobook collection on the home screen. Some prefer high-density visual browsing via cover grid cards, while others require detailed horizontal metadata rows with strict hierarchy rendering derived directly from the SQLite `categories` Nested Set table. The chosen view mode must persist seamlessly across restarts.

## Decision

We will implement a hybrid list layout for the main audiobook collection with multi-level accordion capabilities strictly bound to the database Nested Set:

1. **AppBar Toggle**: Add a view switcher icon button in the `AppBar` next to search/filter controls.
2. **SQLite View Persistence**:
   - Persist user choice in SQLite `settings` table via `LibraryStorage`.
   - Key: `'main_library_view_mode'`, Value: `'list'` | `'grid'`. Default: `'list'`.
   - Loaded on `HomeCubit.init()` startup and saved synchronously upon view toggle interaction.
3. **Grid Layout**: Displays cover-focused vertical tiles containing cover image, title, author, and progress bar/percentage.
4. **List Layout with Strict Nested Set Accordion**:
   - Render hierarchy exclusively from the SQLite `categories` table (`lft ASC`, `depth`, `parent_id`), completely omitting runtime file path string parsing.
   - Attach books strictly via `category_id`. Uncategorized or null `category_id` books hang off a synthetic "Sin categoría" root category.
   - Accordion indentation is 16dp per depth level.
   - Search matches both book metadata and category names, auto-expanding the ancestral path for matching items.
   - Category headers feature node icons, bold typography, book count, total audio duration, and category continuous play action.
   - Node expansion states are remembered across sessions.
5. **Touch Gesture Rules**: Tap category expands/collapses; tap book opens player/details view; long-press opens contextual action sheet.

## Consequences

- Direct alignment with ADR 0022 and ADR 0023.
- Guarantees 100% consistency between stored database category tree, view mode state persistence, and UI list rendering.
