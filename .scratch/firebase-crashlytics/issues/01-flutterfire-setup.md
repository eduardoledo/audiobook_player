# Ticket 01: Setup FlutterFire & Firebase Crashlytics Dependencies

**What to build:**
Add `firebase_core` and `firebase_crashlytics` to `pubspec.yaml`, run `flutterfire configure` to generate `lib/firebase_options.dart`, and link native project settings (`google-services.json` on Android and `GoogleService-Info.plist` on iOS).

**Blocked by:** None (can start immediately).

**Status:** Completed

- [x] `firebase_core` and `firebase_crashlytics` added to `pubspec.yaml`.
- [x] `lib/firebase_options.dart` generated via `flutterfire configure`.
- [x] Android and iOS native build scripts updated with Firebase plugins.
- [x] Application compiles and runs clean.
