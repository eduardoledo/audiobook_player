# Full Bleed Android Launcher Adaptive Icon Specification

## Problem Statement

When launching the application on modern Android devices (Android 8.0+ / API 26+), the app launcher icon displays inside a white squircle system mask with a noticeable white border inset padding around the illustration. The character illustration is rendered as a squarish legacy image inside the mask rather than filling the entire adaptive icon mask area cleanly.

## Solution

Configure Android Adaptive Icons (`ic_launcher.xml`) using `flutter_launcher_icons` by separating the background layer and foreground illustration layer. The foreground artwork will be cropped/scaled to leverage the full safe-zone viewport of the Android adaptive mask, seamlessly extending to the edges without double-padding or white border margins.

## User Stories

1. As an application user, I want the app icon on my Android home screen to fill the entire mask shape, so that the launcher icon looks native, modern, and polished.
2. As an application user, I want the splash screen and launcher icon artwork to maintain consistent character branding without odd padding gaps or double squircle borders.

## Implementation Decisions

- **Adaptive Icon Architecture**: Configure `flutter_launcher_icons` in `pubspec.yaml` with Android adaptive icon properties (`adaptive_icon_background` and `adaptive_icon_foreground`).
- **Foreground Artwork Processing**: Extract/generate a transparent foreground image (`assets/icon_foreground.png`) containing only the character and headphones without pre-baked rounded corners or dark outer padding.
- **Background Layer**: Use solid dark background `#1A1A1A` or matching background asset (`assets/icon_background.png`) so the system mask fills edge-to-edge seamlessly.
- **Resource Generation**: Execute `dart run flutter_launcher_icons` to generate native XML (`mipmap-anydpi-v26/ic_launcher.xml`) and density-specific PNG resources (`mipmap-hdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, `mipmap-xxxhdpi`).

## Testing Decisions

- **Visual Inspection**: Verify the generated `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_foreground.png` assets render cleanly within standard Android icon masks (circle, squircle, rounded square).
- **Static Analysis & Build Verification**: Run `flutter analyze lib/ test/` and `flutter build apk --debug` to ensure zero compilation or build errors.

## Out of Scope

- Changing the underlying character design or mascot image.
- iOS app icon shape modification (iOS applies its own mandatory system mask at build time).

## Further Notes

- Android 12+ (API 31+) splash screen icon guidelines mandate a centered circular viewport for splash icons, distinct from launcher adaptive icons.
