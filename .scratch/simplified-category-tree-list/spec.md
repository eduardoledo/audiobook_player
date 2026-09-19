# Simplified Category Tree List View & Parent Order Specification

## Problem Statement

The main library list rendering previously relied on legacy map grouping (`_groupAudiobooks`) and separate ordering attributes (`universeOrder`, `sagaOrder`, `seriesSequence`). This caused redundant code paths, duplicated sorting logic, and inconsistencies between directory view and list view modes.

## Solution

Simplify `_buildAudiobookList` to render directly from the SQLite `categories` Nested Set table across collapsible levels, replacing separate ordering fields with a single `parent_order` attribute. Audiobooks without an assigned category will be automatically grouped under a "Sin categoría" fallback node displayed at the end of the category list.

## User Stories

1. As an audiobook listener, I want to browse my library grouped by nested category levels (Author, Universe, Saga), so that I can easily navigate complex book series.
2. As an audiobook listener, I want uncategorized books to appear under a clear "Sin categoría" section at the end of the list, so that no book in my library is hidden or missing.
3. As an audiobook listener, I want categories and books to be sorted consistently using a unified `parentOrder` sequence, so that books appear in their correct reading order.

## Implementation Decisions

- **Unified `parent_order` Attribute**:
  - Add `parent_order` (REAL/TEXT) to `categories` table and `CategoryNode` model.
  - Update `Audiobook` model to store `parentOrder` instead of legacy `universeOrder`/`sagaOrder`.
  - Update `AudiobookScanner` to extract folder position numbers and assign them directly to `parentOrder`.

- **Refactored `_buildAudiobookList`**:
  - Remove legacy `_groupAudiobooks` map-grouping code path.
  - Render the category tree recursively using `CategoryNode` items ordered by `lft` and `parent_order`.
  - Append an explicit "Sin categoría" fallback node at the end of the list for books with `categoryId == null`.

- **Database Sync**:
  - Update `rebuildNestedSetFromPatterns()` to persist `parent_order` for categories and audiobooks in SQLite.

## Testing Decisions

- **Testing Seams**:
  - `LibraryStorage` / `AudiobookScanner` integration seam: Verify `parent_order` parsing and Nested Set tree persistence in SQLite.
  - `HomeScreen` widget seam: Verify collapsible category tiles, `parentOrder` sequence sorting, and placement of the "Sin categoría" section at the end of the list.

## Out of Scope

- Modifying the eBook library tab logic.
- Altering the `PathStructureSelectorDialog` UI layout.

## Further Notes

- Respects ADR 0025 and ADR 0027.
