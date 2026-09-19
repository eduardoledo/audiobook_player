# 27. Unified Category Ordering via ParentOrder and Nested Set Category Tree

Date: 2026-09-19

## Status

Accepted

## Context

The main library list rendering previously relied on legacy map grouping (`_groupAudiobooks`) and separate ordering properties spread across different entities (`universeOrder`, `sagaOrder`, `readingOrderKey`). This created duplication, inconsistent ordering logic across UI views, and complex maintenance when rendering nested series or universes.

## Decision

We will unify all category ordering and simplify `_buildAudiobookList` to rely exclusively on the Nested Set category tree:

1. **Unified `parent_order` Field**:
   - Add a `parent_order` (REAL/TEXT) field to the `categories` table and `CategoryNode` model.
   - Replace separate `universeOrder` and `sagaOrder` fields on `Audiobook` with `parentOrder`.
   - Update `AudiobookScanner` to extract sequence numbers or order tokens during directory parsing and assign them directly to `parentOrder`.

2. **Simplified `_buildAudiobookList` & Fallback Category**:
   - Refactor `_buildAudiobookList` to render the `CategoryNode` tree recursively in collapsible levels, using `parent_order` for sorting sibling categories.
   - Remove `_groupAudiobooks` legacy grouping entirely.
   - Automatically assign uncategorized audiobooks to a dedicated "Sin categoría" root category appended at the bottom of the category tree list.

## Consequences

- Eliminates redundant order fields across `Audiobook` and category models.
- Guarantees uniform accordion tree rendering across the application powered by the SQLite Nested Set `categories` table.
- Simplifies `_buildAudiobookList` UI code and removes legacy map-grouping code paths.
