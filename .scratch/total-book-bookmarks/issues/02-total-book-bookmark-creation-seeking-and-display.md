# 02: Total-Book Bookmark Creation, Cross-Chapter Seeking & List Formatting

**What to build:** Make `Bookmark` creation, chronological listing, total-time display, and tap-to-seek operate on the cumulative `1.0x` timeline of the entire `Audiobook` across single-file (`.m4b`) and standard `Multi-File Virtual Audiobook` layouts.

**Blocked by:** 01: Injectable PlayerScreen & Playback Engine Test Seam (Prefactor)

**Status:** resolved

- [x] Adding a `Bookmark` ensures chapter durations are calculated if needed and saves `position_ms` as the cumulative `1.0x` global book timestamp (previous chapters/files duration plus current chapter/file offset) without altering the SQLite `bookmarks` schema or existing rows.
- [x] The `Bookmarks` tab lists bookmarks ordered chronologically across the entire `Audiobook` from start to finish (`position_ms ASC`).
- [x] Each `Bookmark` row displays the user's custom note as the title (falling back to `Bookmark <N>` when empty) and formats its subtitle as `<Global Pos> / <Total Book Duration> (<XX>%) • <Chapter Title>` using global `1.0x` media time only.
- [x] Timestamps pad hours (`HH:MM:SS`) whenever total `Audiobook` duration is 1 hour or longer (`>= 3,600,000 ms`), use `MM:SS` when total duration is under 1 hour, and remain invariant when `Playback Speed` changes (for example `1.5x` or `2.0x`).
- [x] Tapping a `Bookmark` resolves the target audio file/chapter and local offset from global `position_ms`, seeks across files/chapters while preserving the current play/pause state, and skips the 1-second resume rewind on the next Play from pause so playback starts at the exact bookmarked timestamp.
- [x] End-to-end integration tests through the player screen + playback service + SQLite FFI seam verify multi-chapter creation, chronological sorting, `>= 1h` and `< 1h` subtitle formatting, `Playback Speed` invariance, cross-chapter seeking, play/pause preservation, and resume-rewind suppression.
- [x] Static analysis (`flutter analyze lib/`) and the test suite pass with 0 errors and 0 warnings (ADR 0014).

