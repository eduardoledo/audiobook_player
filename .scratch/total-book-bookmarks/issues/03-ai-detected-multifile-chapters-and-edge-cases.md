# 03: AI-Detected Multi-File Chapter Mapping & Metadata Edge-Case Fallbacks

**What to build:** Ensure total-book `Bookmark` creation, logical chapter resolution, cross-file seeking, and list display remain accurate when a `Multi-File Virtual Audiobook` uses AI-detected `Embedded & Virtual Chapters` whose boundaries differ from physical audio files, as well as when metadata is incomplete or timestamps sit at boundary limits.

**Blocked by:** 02: Total-Book Bookmark Creation, Cross-Chapter Seeking & List Formatting

**Status:** resolved

- [x] When an `Audiobook` has multiple physical audio files and its `Embedded & Virtual Chapters` count or boundaries differ from its physical files (such as after AI structure detection), per-file durations are resolved and cached so `Bookmark` creation and cross-file seeking still map accurately between global `position_ms` and `(fileIndex, localFileOffset)`.
- [x] In that decoupled layout, each `Bookmark` subtitle still resolves and displays the containing logical chapter title based on global `start`/`end` chapter boundaries (clamping the exact end-of-book timestamp to the final chapter).
- [x] When total `Audiobook` duration is `0` (unreadable metadata), bookmark subtitles omit `/ <Total Book Duration> (<XX>%)` without divide-by-zero errors or `/ 00:00` output; when the chapter list is empty, the `• <Chapter Title>` suffix is omitted cleanly.
- [x] Seeking to a legacy or boundary `Bookmark` whose `position_ms` is `0` or exceeds total book duration clamps safely within valid file and offset bounds without throwing errors.
- [x] End-to-end integration tests verify decoupled multi-file + AI-detected chapter bookmark creation, chapter label resolution, cross-file seeking, zero-duration/empty-chapter fallbacks, and out-of-range clamping.
- [x] Static analysis (`flutter analyze lib/`) and the test suite pass with 0 errors and 0 warnings (ADR 0014).

