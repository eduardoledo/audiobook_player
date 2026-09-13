# Ticket 01: Add getAllCategories to LibraryStorage & BLoC HomeState Categories

Status: ready-for-agent
Type: task

## Description

Expose `getAllCategories()` in `LibraryStorage` and add `categories` (`List<CategoryNode>`) to `HomeState` and `HomeCubit`.

## Requirements

1. Update `lib/services/library_storage.dart`:
   - Implement `Future<List<CategoryNode>> getAllCategories() async`: execute `SELECT * FROM categories ORDER BY lft ASC`.
2. Update `lib/bloc/home_state.dart`:
   - Add `categories` (`List<CategoryNode>`) property to `HomeState` and update `copyWith` and `props`.
3. Update `lib/bloc/home_cubit.dart`:
   - Fetch `getAllCategories()` in `loadData()`, `scanDirectory()`, and `rescanAll()` and pass them to `HomeState`.

## Verification

- `flutter analyze lib/` passes with 0 errors and 0 warnings.
- `flutter test` passes.
