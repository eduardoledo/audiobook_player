# Simplified Category Tree List View & Parent Order Specification

## Problem Statement

The main library list rendering in `_buildAudiobookList` and `_buildEbookList` previously relied on legacy map grouping (`_groupAudiobooks`) and separate ordering attributes (`universe`, `universeOrder`, `saga`, `seriesSequence`). Additionally, the `PathStructureSelectorDialog` and `PathSegmentRole` enum exposed obsolete role labels (`universe`, `saga`, `era`) that do not fit the unified SQLite Nested Set category system.

## Solution

Refactor both `_buildAudiobookList` and `_buildEbookList` to render directly from the SQLite `categories` Nested Set table across collapsible levels. Update `PathSegmentRole` to replace obsolete roles (`universe`, `saga`, `era`) with a unified `category` role ("Categoría / Subcategoría") and adapt `PathStructureSelectorDialog`. Add automatic SQLite migration for saved pattern rules.

## User Stories

1. As a user, I want to browse both my audiobooks and eBooks grouped under Authors as the level-0 virtual root, with nested categories displayed beneath each author.
2. As a user, I want uncategorized audiobooks and eBooks for a specific author to appear at the top of that author's section before their subcategories.
3. As a user, I want books without an assigned author to appear in a "Sin categoría" fallback group at the end of the entire list.
4. As a user, I want categories and books (both audiobooks and eBooks) sorted by `parentOrder` first and title/name naturally second.
5. As a user, I want to configure directory path patterns using clear category roles ("Categoría / Subcategoría") in the `PathStructureSelectorDialog`.

## Implementation Decisions

- **PathSegmentRole & PathStructureSelectorDialog Updates**:
  - Update `PathSegmentRole` enum: replace `universe`, `saga`, `era` with `category` ("Categoría / Subcategoría").
  - Update default heuristic in `PathStructureSelectorDialog` to assign `category` for all intermediate path segments between `author` and `bookTitle`.

- **SQLite Rule Migration**:
  - Add migration logic in `LibraryStorage` when reading/upgrading path pattern rules to transform legacy JSON strings (`'universe'`, `'saga'`, `'era'`) to `'category'`.

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
  - `PathSegmentRole` / `PathStructureSelectorDialog` widget tests: Verify selection of `category` role and migration of legacy saved rules.
  - `Ebook` model unit tests: Verify `parentOrder` field serialization/deserialization.
  - `HomeScreen` widget seam: Verify author level 0 tiles and nested category subtrees in both `_buildAudiobookList` and `_buildEbookList`.

## Out of Scope

- None.
