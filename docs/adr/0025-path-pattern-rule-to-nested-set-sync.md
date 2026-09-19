# 25. Path Pattern Rule to Nested Set Category Tree Synchronization & Conflict Resolution

Date: 2026-09-17

## Status

Accepted

## Context

Users can configure custom directory structure mapping rules per scan root via `PathStructureSelectorDialog`. When saving a pattern rule, the application previously saved the pattern definition but relied on delayed background library scanning to rebuild categories or left categories out-of-sync. 

To maintain strict alignment with ADR 0022 and ADR 0024 (where library list rendering relies exclusively on the SQLite `categories` Nested Set table), saving a pattern rule must immediately scan all filesystem paths under all active scan roots, construct the global Nested Set category tree (`lft`, `rgt`, `depth`, `parent_id`, `path_prefix`), update category assignments (`category_id`) across all stored audiobooks, and enforce strict conflict validation across overlapping scan roots.

## Decision

We will implement active Nested Set category synchronization and path pattern conflict resolution upon saving path rules:

1. **Active Filesystem & Nested Set Sync on Save Pattern**:
   - When tapping "Guardar Patrón" in `PathStructureSelectorDialog`, inspect all active scan roots in the file system.
   - For every directory segment assigned a domain role (`author`, `universe`, `saga`), construct or retrieve the corresponding `CategoryNode` in the Nested Set tree.
   - Assign each discovered `Audiobook` its exact foreign key `category_id` in SQLite.
   - Recalculate `lft`, `rgt`, `depth`, and `path_prefix` globally across the `categories` table.

2. **Sequential Conflict Detection & User Decision**:
   - **Step 1: Overlapping Path Validation**: Check if the target `rootPath` overlaps (is subpath or parent of) an existing saved `PathPatternRule` root.
   - **Step 2: Category Name Hierarchy Conflict Validation**: Check if the resulting tree introduces conflicting roles or category names at identical depth levels for the same physical subdirectories.
   - **Conflict Action Dialog**: If a conflict is detected, present the user with an explicit decision choice:
     - **Keep Existing Pattern**: Cancel the operation and retain the previous rule.
     - **Replace with New Pattern**: Overwrite the conflicting rule and perform a complete global Nested Set recalculation across all active roots.

3. **Domain & Storage API Additions**:
   - Add `PathPatternRule.relativePaths` or association mapping to bind categories to one or more root-relative directory paths.
   - Expose `rebuildNestedSetFromPatterns()` on `LibraryStorage` / `HomeCubit`.

## Consequences

- Guarantees instant UI updates without waiting for full media rescans when path pattern rules change.
- Prevents invalid or conflicting category hierarchies across overlapping library scan paths.
- Enforces strict adherence to the SQLite `categories` Nested Set model across the application.
