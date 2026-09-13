# Background App Build & Deployment Policy

Whenever building, installing, or launching the application (`flutter run`, `flutter build`, `adb install`), execute the command as a non-blocking background task without waiting or polling in a loop, allowing the main agent turn to return immediately and continue the development workflow.
