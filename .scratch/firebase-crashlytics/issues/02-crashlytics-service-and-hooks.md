# Ticket 02: Implement CrashlyticsService & Global Error Handlers

**What to build:**
Create `CrashlyticsService` registered via `getIt` to handle crash reporting, breadcrumb logging, and custom key management. Automatically calculate and set `category_hierarchy_path` (e.g. `"Brandon Sanderson > Cosmere > Mistborn"`) from active book paths and SQLite `categories`. Configure `main()` error hooks for `FlutterError.onError` and `PlatformDispatcher.instance.onError` with Crashlytics collection enabled in both Debug and Release modes.

**Blocked by:** 01-flutterfire-setup.md

**Status:** Completed

- [x] `CrashlyticsService` created and registered in `service_locator.dart`.
- [x] `category_hierarchy_path` custom key calculated from SQLite `categories` Nested Set hierarchy and set on Crashlytics.
- [x] Global error hooks (`FlutterError.onError`, `PlatformDispatcher.instance.onError`) bound in `main()`.
- [x] Data collection explicitly enabled for Debug and Release modes.
