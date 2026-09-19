# Ticket 02: Active Nested Set Hierarchy Synchronization on Save Pattern

## Status: Completed

## Description
Implement active category tree construction and global Nested Set recalculation upon pattern rule save.

## Acceptance Criteria
- Explore filesystem subdirectories under registered scan roots according to saved `PathPatternRule` definitions.
- Create missing `CategoryNode` records in SQLite `categories` table.
- Recalculate `lft`, `rgt`, `depth`, `parent_id`, and `path_prefix` globally across all categories.
- Update `category_id` on all affected `Audiobook` records.
- Notify `HomeCubit` to refresh library UI state immediately.
