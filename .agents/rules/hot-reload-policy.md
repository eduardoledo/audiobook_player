# Hot Reload & In-Place App Update Policy

Always follow these execution rules when running or modifying the application:

1. **Automatic Hot Reload**: Whenever code changes are made while the Flutter application is running on a connected device/emulator, immediately send a Hot Reload (`r` / `hot_reload`) without asking the user for confirmation.
2. **In-Place App Update / Hot Restart**: If a Hot Reload is insufficient (e.g. native code changes, plugin additions, or schema migrations), execute a Hot Restart (`R` / `hot_restart`) or run `flutter run -d <device>` to update the app in-place without uninstalling, also without asking for confirmation.
