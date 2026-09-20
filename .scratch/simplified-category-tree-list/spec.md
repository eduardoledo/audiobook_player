# Simplified Category Tree List View & Parent Order Specification

## Problem Statement

The main library list rendering in `_buildAudiobookList` and `_buildEbookList` previously relied on legacy map grouping (`_groupAudiobooks`) and separate ordering attributes (`universe`, `universeOrder`, `saga`, `seriesSequence`). This created redundant code paths, duplicated sorting logic, and legacy UI structures that did not cleanly reflect the SQLite Nested Set `categories` tree.

## Solution

Refactor both `_buildAudiobookList` and `_buildEbookList` to render directly from the SQLite `categories` Nested Set table across collapsible levels, completely removing legacy map grouping and references to `universe`/`saga` UI wrappers. Add `parentOrder` property to the `Ebook` model for unified ordering across both library views.

## User Stories

1. As a user, I want to browse both my audiobooks and eBooks grouped under Authors as the level-0 virtual root, with nested categories displayed beneath each author.
2. As a user, I want uncategorized audiobooks and eBooks for a specific author to appear at the top of that author's section before their subcategories.
3. As a user, I want books without an assigned author to appear in a "Sin categoría" fallback group at the end of the entire list.
4. As a user, I want categories and books (both audiobooks and eBooks) sorted by `parentOrder` first and title/name naturally second, with no forced numerical prefixes in titles by default.

## Implementation Decisions

- **Model Updates**:
  - Add `parentOrder` (`double?`) property to `Ebook` model, constructor, `fromJson`, `toJson`, and `copyWith`.

- **Author Level 0 Virtual Nodes**:
  - `book.author` acts as the virtual level 0 container in `_buildAudiobookList` and `_buildEbookList`.
  - Under each author:
    - Books belonging to that author with `categoryId == null` are rendered first at the top of the author's list.
    - `CategoryNode` items matching the author's hierarchy descend recursively below the uncategorized books.

- **Fallback "Sin categoría" Group**:
  - Books with `author == 'Unknown'` or empty author (and no assigned category) are placed under a single "Sin categoría" root tile at the very bottom of the library list.

- **Ordering & Title Formatting**:
  - Order children (both category nodes and books) primarily by `parentOrder` (ascending) and secondarily by title/name using natural sort (`_naturalCompare`).
  - Do not prepend `parentOrder` numbers to category titles or book titles in the UI by default.

- **Removal of Legacy Logic**:
  - Delete legacy map-grouping code completely.
  - Remove all UI references to `Universo:` labels and `seriesMap`/`universeMap` nested maps.

## Testing Decisions

- **Testing Seams**:
  - `Ebook` model unit tests: Verify `parentOrder` field serialization/deserialization.
  - `HomeScreen` widget seam: Verify author level 0 tiles and nested category subtrees in both `_buildAudiobookList` and `_buildEbookList`.

## Out of Scope

- Altering the `PathStructureSelectorDialog` UI layout.
