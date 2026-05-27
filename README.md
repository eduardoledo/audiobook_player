# Audiobook Player

A Flutter app for playing audiobooks with chapter support. Scan directories for audiobooks (.m4b) and play them with full chapter navigation.

## Features

- **Directory picker** – Select folders to scan for audiobooks
- **Recursive scanning** – Finds all .m4b, .m4a, .mp3 files in selected directories and subdirectories
- **Chapter support** – Uses `chapters.json` when present for chapter metadata and navigation
- **Playback controls** – Play, pause, skip ±10 seconds, seek bar
- **Chapter list** – Jump to any chapter from the player screen

## Running the app

**Desktop (recommended):**
```bash
cd audiobook_player
flutter run -d macos   # or windows, linux
```

**Web:**
```bash
flutter run -d chrome
```
Note: File/directory access is limited on web. Use desktop for full functionality.

## Usage

1. Tap **"Add folder to scan"** to open the directory picker
2. Select a folder containing audiobooks (e.g. your Robert Ludlum collection)
3. The app scans for .m4b files and loads `chapters.json` when available
4. Tap any audiobook to start playback
5. Use the list icon in the player to show/hide the chapter list

## Project structure

```
lib/
├── main.dart              # App entry
├── models/
│   └── audiobook.dart     # Audiobook & Chapter models
├── services/
│   ├── audiobook_scanner.dart   # Scans directories for audiobooks
│   ├── audio_player_service.dart # just_audio playback
│   └── library_storage.dart     # Persists scan paths & library
└── screens/
    ├── home_screen.dart   # Library + directory picker
    └── player_screen.dart # Playback UI with chapters
```

## Dependencies

- `file_picker` – Directory selection
- `just_audio` – Audio playback
- `shared_preferences` – Persist library
- `path` – Path handling
