# 01: Per-Book Isolated State & Dynamic Short Rewind

**What to build:**
Isolated per-book playback state management (playback speed, volume gain, position) saved in SQLite (`sqflite`), alongside automatic dynamic short rewind on resuming playback based on elapsed pause duration.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] SQLite database schema updated to isolate playback state per `Audiobook`
- [x] Changing active book saves and restores individual playback speed, volume gain, and millisecond position
- [x] Resuming playback after pause applies dynamic short rewind (2s for <5m, 5s for <15m, 10s for <1h, 20s for <8h, 30s for >8h)
- [x] Unit tests for short rewind calculator and per-book state repository
