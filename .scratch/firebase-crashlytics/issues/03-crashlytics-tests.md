# Ticket 03: Unit & Integration Tests for Crashlytics Error Pipeline

**What to build:**
Add unit and integration tests for `CrashlyticsService` and error handlers, verifying that uncaught exceptions trigger error recording, breadcrumb logs are formatted properly, and `category_hierarchy_path` is correctly generated for given audiobook paths.

**Blocked by:** 02-crashlytics-service-and-hooks.md

**Status:** Completed

- [x] Unit tests for `CrashlyticsService` custom key formatting and error logging.
- [x] Unit tests verifying `category_hierarchy_path` computation against Nested Set category nodes.
- [x] Integration test verifying error hooks forward exceptions to Crashlytics.
- [x] All tests pass with 0 analyzer errors.
