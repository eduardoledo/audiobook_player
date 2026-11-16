# Spec: Total-Book-Aware Bookmarks

Status: resolved

## Problem Statement

When listening to a `Multi-File Virtual Audiobook`, creating a `Bookmark` currently records only the local playback offset within the active audio file rather than the cumulative timestamp across the entire `Audiobook`. As a result:

- Bookmarks created in later chapters store small local timestamps (for example `03:15` in Chapter 5 instead of `02:03:15` in the book), breaking chronological ordering across chapters.
- Tapping a `Bookmark` seeks to that millisecond offset inside whichever audio file happens to be active instead of switching to the target audio file and offset across the book.
- The `Bookmarks` tab displays only a bare local timestamp with no indication of total `Audiobook` duration, overall completion percentage, or chapter context.
- Resuming from pause after tapping a `Bookmark` applies the 1-second resume rewind, landing slightly before the exact bookmarked moment.

## Solution

Make every `Bookmark` operate on the canonical `1.0x` cumulative timeline of the entire `Audiobook`. Persist `position_ms` as the global book timestamp (preserving the existing SQLite schema and existing rows), dynamically map between global book timestamps and physical audio file offsets as well as logical `Embedded & Virtual Chapters`, display rich total-book context (`<Global Pos> / <Total Book Duration> (<XX>%) • <Chapter Title>`) in the `Bookmarks` tab, and seek accurately across files and chapters while preserving play/pause state and landing on the exact bookmarked timestamp.

## User Stories

1. As an audiobook listener playing a `Multi-File Virtual Audiobook`, I want creating a `Bookmark` in any chapter to record my cumulative position across the entire `Audiobook`, so that the saved timestamp reflects how far into the whole book the moment occurred.
2. As an audiobook listener playing a single-file `.m4b` `Audiobook` with `Embedded & Virtual Chapters`, I want creating a `Bookmark` to record the exact global position within the book, so that single-file and multi-file books behave identically.
3. As an audiobook listener who opens a book whose chapter durations have not yet been calculated, I want `Bookmark` creation to ensure chapter and file durations are resolved before saving, so that cumulative timestamps from earlier chapters are never recorded as zero.
4. As an audiobook listener viewing the `Bookmarks` tab, I want bookmarks sorted chronologically from the beginning to the end of the `Audiobook`, so that a bookmark in Chapter 2 always appears before a bookmark in Chapter 10 regardless of their within-chapter offsets.
5. As an audiobook listener viewing the `Bookmarks` tab, I want each bookmark's title to show my custom note if I entered one or fall back to `Bookmark N`, so that both labeled and quick unlabeled bookmarks are easy to scan.
6. As an audiobook listener viewing the `Bookmarks` tab, I want each bookmark's subtitle to show `<Global Pos> / <Total Book Duration> (<XX>%) • <Chapter Title>` using global time only, so that I immediately see where the bookmark sits relative to the total `Audiobook` length and which chapter it belongs to.
7. As an audiobook listener listening to an `Audiobook` that is 1 hour or longer, I want bookmark timestamps under 1 hour to pad hours as `HH:MM:SS` (for example `00:05:12 / 12:45:00 (1%) • Chapter 1`), so that the bookmark timestamp aligns visually with the total book duration format.
8. As an audiobook listener listening to a short `Audiobook` under 1 hour, I want both the bookmark timestamp and total book duration formatted as `MM:SS` (for example `05:12 / 45:00 (12%) • Chapter 1`), so that short books avoid unnecessary `00:` hour prefixes.
9. As an audiobook listener listening at a non-`1.0x` `Playback Speed` (such as `1.5x` or `2.0x`), I want bookmark timestamps and total book duration to always use canonical `1.0x` media time, so that bookmark timestamps remain stable and match chapter start times regardless of speed changes.
10. As an audiobook listener who taps a `Bookmark` while audio is playing, I want playback to jump immediately to the exact target audio file and offset for that global book timestamp and continue playing seamlessly, so that I can navigate across chapters in a single tap.
11. As an audiobook listener who taps a `Bookmark` while audio is paused, I want the player to seek to the exact target audio file and offset while remaining paused, and then start from that exact timestamp without applying the 1-second resume rewind when I press Play, so that playback begins precisely where I placed the bookmark.
12. As an audiobook listener who used AI structure detection on a `Multi-File Virtual Audiobook` (where logical `Embedded & Virtual Chapters` do not map 1-to-1 to physical audio files), I want `Bookmark` creation, chapter resolution, and cross-file seeking to still resolve physical file offsets and logical chapter titles accurately, so that custom detected chapters never break bookmark navigation.
13. As an audiobook listener with pre-existing bookmarks stored in my local library database or `Local Library Backup` archives, I want existing `Bookmark` records to load without database migrations or data loss, so that upgrading the app never breaks my library or backups.
14. As an audiobook listener opening an `Audiobook` with unreadable duration metadata (`0` total duration) or empty chapters, I want bookmarks to fall back cleanly to displaying available timestamp information without divide-by-zero errors or `/ 00:00` artifacts, so that the UI remains resilient on incomplete metadata.

## Implementation Decisions

- **Canonical Global Timestamp Storage**: Keep `position_ms` in the `bookmarks` SQLite table and `Local Library Backup` payloads as the single source of truth representing cumulative `1.0x` milliseconds from the start of the `Audiobook`. No SQLite schema version bump or destructive migration is performed; pre-existing rows remain intact and are interpreted as global `position_ms`.
- **Chronological Ordering**: Rely on ascending `position_ms` ordering from storage so bookmarks across all files and chapters naturally sort from the start to the end of the `Audiobook`.
- **Global Position Calculation on Creation**: Ensure chapter/file durations are calculated prior to computing the global timestamp when adding a bookmark, summing the durations of all preceding physical audio files plus the active file's current playback offset (or using the single file's playback offset directly for single-file books).
- **Dynamic Bijection Between Global Timeline, Physical Files, and Logical Chapters**:
  - Maintain a clean timeline mapping contract on the playback service layer that converts `(activeFileIndex, localFileOffset) -> globalBookPosition` and `globalBookPosition -> (targetFileIndex, localFileOffset)` as well as resolving the containing logical `Chapter` (`start <= globalSeconds < end`, clamping the book endpoint to the final chapter).
  - For single-file books, `targetFileIndex` is `0` and `localFileOffset` equals `globalBookPosition` (clamped to file duration).
  - For `Multi-File Virtual Audiobook` books where chapters correspond 1-to-1 with physical files, derive per-file durations directly from `Audiobook` chapters.
  - For `Multi-File Virtual Audiobook` books where AI structure detection produced logical chapters independent of physical file count, resolve and cache per-file durations per loaded `Audiobook` so physical file seeking and global position capture remain exact while logical chapter titles still resolve against `Embedded & Virtual Chapters`.
- **Play/Pause Preservation and Resume-Rewind Suppression**: Seeking to a `Bookmark` must not alter whether playback is currently playing or paused. In addition, seeking to a `Bookmark` clears the pending 1-second resume-rewind flag so pressing Play from a paused state begins at the exact bookmarked timestamp (respecting ADR 0002 while matching explicit seek semantics).
- **Bookmarks List Presentation**:
  - **Title**: Display the user's custom label/note when non-empty; otherwise display `Bookmark <index + 1>`.
  - **Subtitle**: Display `<Global Pos> / <Total Book Duration> (<XX>%) • <Chapter Display Title>` using `1.0x` media duration and rounded integer percentage (`(globalMs / totalMs * 100).round().clamp(0, 100)`). Strip redundant part prefixes from chapter display titles consistently with the Chapters tab, or include part context cleanly when present.
  - **Duration Padding**: Format both `<Global Pos>` and `<Total Book Duration>` as `HH:MM:SS` whenever total book duration is at least 1 hour (`>= 3,600,000 ms`), and as `MM:SS` when total book duration is under 1 hour.
  - **Fallbacks**: If total book duration is `0`, omit `/ <Total Book Duration> (<XX>%)` and show `<Global Pos>` (plus `• <Chapter Display Title>` if available). If the chapter list is empty, omit the `• <Chapter Display Title>` suffix.
- **Injectable Dependencies Alignment (ADR 0020)**: Allow the player screen to accept injected playback service and storage dependencies (defaulting to the service locator for existing call sites) and isolate the low-level audio engine and file-duration probe seam inside the playback service so the full feature can be exercised deterministically without platform audio channels.
- **Quality Invariant (ADR 0014)**: All changes must keep static analysis (`flutter analyze lib/`) and test suites 100% clean with zero errors and zero warnings.

## Testing Decisions

- **What Makes a Good Test**: Tests must verify observable user-facing and persistence behavior—what global `position_ms` gets stored when adding a bookmark in a later chapter, how bookmark subtitles render in the `Bookmarks` tab across book lengths and playback speeds, and which physical file index, offset, and play/pause state the audio engine lands on when tapping a bookmark and subsequently pressing Play—never private helper internals.
- **Single High-Level Integration Seam**: Exercise the feature end-to-end through a single top-level player screen widget + playback service + real SQLite FFI (`sqflite_common_ffi`) integration seam, stubbing only the low-level platform audio player and filesystem audio-duration probe seam.
- **Modules Covered Through This Seam**:
  - Player screen bookmark creation dialog, `Bookmarks` tab rendering, duration padding, speed invariance, and tap navigation.
  - Playback service global position calculation, cross-file seeking (single-file `.m4b`, 1-to-1 multi-file, and multi-file with AI-detected chapters), play/pause preservation, and 1-second resume-rewind suppression.
  - Library storage SQLite persistence and ascending `position_ms` chronological retrieval.
- **Prior Art in Repository**:
  - SQLite FFI bookmark persistence tests (`sqflite_common_ffi` initialization and real database queries).
  - Playback resume-rewind unit tests verifying 1-second rewind behavior.
  - Player widget sheet tests pumping Material test harnesses with `flutter_test`.

## Out of Scope

- Visual bookmark pins or tick markers rendered on the `Total Book` or chapter progress bars.
- Scaling bookmark timestamps or total book durations dynamically by `Playback Speed`.
- Destructive migration, heuristic rewriting, or deletion of pre-existing `Bookmark` rows in SQLite.
- Changes to voice/audio snippet recording UI beyond preserving existing `Bookmark` fields (`textNote`, `audioNotePath`, `createdAt`).

## Further Notes

- Respects ADR 0002 (Short Rewind on Resume), ADR 0005 (M4B Support & Virtual Multi-file Stitching), ADR 0014 (Zero Current Problems Quality Invariant), and ADR 0020 (Flutter Clean Architecture and Constructor Injection).

