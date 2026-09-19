Status: ready-for-agent

# 01: View Mode State & SQLite Settings Persistence

**What to build:** Users can tap a view switcher toggle button in the main screen `AppBar` to alternate between Grid and List layouts. The selected layout preference (`'list'` or `'grid'`) is saved to the SQLite `settings` table and restored automatically on app restart.

**Blocked by:** None (can start immediately)

## Acceptance Criteria

- [ ] `HomeCubit` initializes with `main_library_view_mode` loaded from SQLite `settings` table via `LibraryStorage` (defaulting to `'list'`).
- [ ] An icon toggle button is visible in `HomeScreen` `AppBar` next to search/filters.
- [ ] Tapping the toggle switches `HomeState.viewMode` and writes the new mode immediately to SQLite `settings` under key `'main_library_view_mode'`.
- [ ] Restarting the app restores the previously saved view mode.
- [ ] Integration tests in `test/bloc/` verify loading and persisting `main_library_view_mode`.
