# Simplified Category Tree List View & Parent Order Specification

## Problem Statement

The main library list rendering in `_buildAudiobookList` previously relied on legacy map grouping (`_groupAudiobooks`) and separate ordering attributes (`universe`, `universeOrder`, `saga`, `seriesSequence`). This created redundant code paths, duplicated sorting logic, and legacy UI structures that did not cleanly reflect the SQLite Nested Set `categories` tree.

## Solution

Refactor `_buildAudiobookList` to render directly from the SQLite `categories` Nested Set table across collapsible levels, completely removing legacy `_groupAudiobooks` and references to `universe`/`saga` UI wrappers.

## User Stories

1. As an audiobook listener, I want to browse my library grouped under Authors as the level-0 virtual root, with nested categories displayed beneath each author.
2. As an audiobook listener, I want uncategorized books for a specific author to appear at the top of that author's section before their subcategories.
3. As an audiobook listener, I want books without an assigned author to appear in a "Sin categoría" fallback group at the end of the entire list.
4. As an audiobook listener, I want categories and books sorted by `parentOrder` first and title/name naturally second, with no forced numerical prefixes in titles by default.

## Implementation Decisions

- **Author Level 0 Virtual Nodes**:
  - `book.author` acts as the virtual level 0 container in `_buildAudiobookList`.
  - Under each author:
    - Audiobooks belonging to that author with `categoryId == null` are rendered first at the top of the author's list.
    - `CategoryNode` items matching the author's hierarchy descend recursively below the uncategorized books.

- **Fallback "Sin categoría" Group**:
  - Audiobooks with `author == 'Unknown'` or empty author (and no assigned category) are placed under a single "Sin categoría" root tile at the very bottom of the library list.

- **Ordering & Title Formatting**:
  - Order children (both category nodes and books) primarily by `parentOrder` (ascending) and secondarily by title/name using natural sort (`_naturalCompare`).
  - Do not prepend `parentOrder` numbers to category titles or audiobook titles in the UI by default.

- **Removal of Legacy Logic**:
  - Delete `_groupAudiobooks` map-grouping method completely.
  - Remove all UI references to `Universo:` labels and `seriesMap`/`universeMap` nested maps.

## Testing Decisions

- **Testing Seams**:
  - `HomeScreen` widget seam: Verify author level 0 tiles, placement of author-level uncategorized books at the top of author sections, placement of global uncategorized/authorless books at the bottom of the list, and absence of legacy universe labels.

## Out of Scope

- Modifying eBook library tab logic.
- Altering the `PathStructureSelectorDialog` UI layout.
