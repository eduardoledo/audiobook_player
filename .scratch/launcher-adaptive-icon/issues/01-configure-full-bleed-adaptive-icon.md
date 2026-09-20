# 01: Configure Full Bleed Android Launcher Adaptive Icon

**What to build:**
Configure Android Adaptive Icon using `flutter_launcher_icons` so that the app mascot fills the Android system launcher squircle mask completely without white double-border margins or excessive inset padding.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Create/configure `adaptive_icon_background` and `adaptive_icon_foreground` in `pubspec.yaml` under `flutter_icons`.
- [x] Ensure foreground asset contains transparent padding so mascot artwork scales to fill the active viewport safe-zone.
- [x] Run `dart run flutter_launcher_icons` to generate native XML (`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`) and Android density mipmap PNG assets.
- [x] Verify `flutter analyze lib/ test/` reports 0 static analysis errors.
