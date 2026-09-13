# Ticket 01: Nested Set Categories SQLite Schema & CategoryNode Model

Status: resolved
Type: task

## Description

Create the `CategoryNode` Dart model and add the `categories` table schema to `LibraryStorage` in SQLite. Bump the database version to 13 and add `category_id` column to `audiobooks` and `ebooks` tables.

## Requirements

1. Create `lib/models/category_node.dart`:
   - Properties: `id` (int?), `name` (String), `lft` (int), `rgt` (int), `depth` (int), `parentId` (int?), `pathPrefix` (String).
   - `toMap()` and `fromMap()` factory constructors.
2. Update `lib/models/audiobook.dart` and `lib/models/ebook.dart`:
   - Add `categoryId` (int?) field with JSON serialization support.
3. Update `lib/services/library_storage.dart`:
   - Bump DB version to 13 in `openDatabase`.
   - Create `categories` table with `id`, `name`, `lft`, `rgt`, `depth`, `parent_id`, `path_prefix`.
   - Add `category_id` column migration for `audiobooks` and `ebooks` tables.

## Verification

- `flutter analyze lib/` passes with 0 errors and 0 warnings.
- `flutter test` passes.
