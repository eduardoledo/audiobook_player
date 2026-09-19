# 26. Firebase Crashlytics Integration & Global Error Logging Strategy

Date: 2026-09-19

## Status

Accepted

## Context

As the application grows with offline media scanning, SQLite persistence, audio playback services (`just_audio`, `audio_session`), and eBook rendering, unhandled exceptions in native code, background isolates, or Flutter UI loops can result in app crashes without diagnostic visibility.

To ensure stability, real-time error tracking, and proactive post-mortem analysis across Android and iOS releases, we need a centralized, low-overhead crash reporting service. The user requested integrating Google Crashlytics using an existing Google account.

## Decision

We will integrate **Firebase Crashlytics** and **Firebase Core** into the Flutter codebase:

1. **FlutterFire CLI Setup**:
   - Use `flutterfire configure` to generate `lib/firebase_options.dart` and bind native configuration files (`google-services.json` for Android and `GoogleService-Info.plist` for iOS).

2. **Dual-Environment Reporting (Debug & Release)**:
   - Keep Crashlytics data collection **enabled in both Debug and Release modes** (`FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)`), allowing continuous crash capture during local developer testing and production builds.

3. **Global Error Hook Pipeline**:
   - **Flutter UI Errors**: Override `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`.
   - **Asynchronous / Platform Errors**: Pass `PlatformDispatcher.instance.onError` unhandled exceptions to `FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)`.

4. **Rich Contextual Logging**:
   - Add custom keys (`FirebaseCrashlytics.instance.setCustomKey()`) for current active book path (`current_book_path`), complete category hierarchy path generated from the book path (`category_hierarchy_path`), playback state (`is_playing`), view mode (`library_view_mode`), and database version.
   - Record breadcrumb logs (`FirebaseCrashlytics.instance.log()`) during major lifecycle events (e.g. scan start/finish, playback error, database migration).

## Consequences

- Real-time diagnostic reports with full symbolicated stack traces in the Firebase Console.
- Slightly increased app bundle size due to Firebase SDK dependencies.
- Ability to pinpoint playback and SQLite crashes on specific Android device models or iOS versions.
