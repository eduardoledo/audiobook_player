# Firebase Crashlytics Integration Specification

## Problem Statement

When the audiobook player app experiences runtime exceptions or crashes (e.g. background audio service errors, SQLite locks, eBook parsing failures, or UI rendering glitches), there is no centralized remote reporting mechanism. Developers cannot monitor app health, track crash frequencies across device models, or receive detailed stack traces from real-world usage.

## Solution

Integrate `firebase_core` and `firebase_crashlytics` into the Flutter application. Configure global error handlers to automatically record synchronous Flutter framework errors, unhandled asynchronous platform errors, and native crashes. Enrich crash reports with contextual custom keys (active book path, player state, view mode) and breadcrumb logs.

## User Stories

1. As a mobile app developer, I want all uncaught Flutter UI exceptions to be recorded in Firebase Crashlytics, so that I can fix UI crashes promptly.
2. As a mobile app developer, I want unhandled asynchronous errors from isolates and platform dispatchers to be captured in Crashlytics, so that I don't miss background audio or storage crashes.
3. As a developer inspecting a crash report in the Firebase Console, I want to see contextual key-value pairs (e.g. `current_book_path`, `category_hierarchy_path`, `is_playing`), so that I can reproduce exact crash scenarios.
4. As a developer, I want breadcrumb logs recorded during key operations (scanning, playback state changes, database migrations), so that I can trace the sequence of user actions leading up to a crash.
5. As a developer running local debug builds, I want Crashlytics collection to remain active during debug sessions, so that I can test error reporting before releasing to production.

## Implementation Decisions

- **FlutterFire CLI Setup**:
  - Run `flutterfire configure` to generate `lib/firebase_options.dart` and bind native configuration files (`google-services.json` and `GoogleService-Info.plist`).
- **Dependencies**:
  - Add `firebase_core` and `firebase_crashlytics` to `pubspec.yaml`.
- **Global Error Hooks**:
  - In `main()`, initialize Firebase via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
  - Set `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`.
  - Pass `PlatformDispatcher.instance.onError` to `FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)`.
  - Explicitly enable collection: `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)`.
- **Contextual Logging Service (`CrashlyticsService`)**:
  - Encapsulate Crashlytics calls behind a service layer (`CrashlyticsService`) registered with `getIt`.
  - Expose helper methods: `log(String message)`, `setCustomKey(String key, dynamic value)`, and `recordError(dynamic exception, StackTrace? stack)`.
  - Include automatic lookup and setting of `category_hierarchy_path` (e.g. `"Brandon Sanderson > Cosmere > Mistborn"`) computed from the active book path and SQLite `categories` Nested Set table.

## Testing Decisions

- Test external behavior by mocking `CrashlyticsService` or verifying that error handlers invoke `recordError` when exceptions occur.
- Verify through unit tests that `CrashlyticsService` properly formats custom keys and logs.
- Prior art: `LibraryStorage` unit tests and `FakeLibraryStorage` test helpers.

## Out of Scope

- Firebase Analytics or User Performance Monitoring (strictly Crashlytics scope).
- User consent opt-out UI toggle for Crashlytics reporting (all crashes enabled per user decision).

## Further Notes

- Firebase project configuration requires running `flutterfire configure` with an active Google/Firebase account.
