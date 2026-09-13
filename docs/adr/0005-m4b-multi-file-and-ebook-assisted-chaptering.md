# 5. M4B Support, Virtual Folder Playlists, and eBook-Assisted Chapter Verification

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Audiobooks come in various file distributions: single M4B files with embedded TOCs, folders containing dozens of individual MP3s, or monolithic single MP3 files without chapter metadata. We need a flexible chaptering architecture that supports both embedded metadata, virtual multi-file stitching, and intelligent chapter verification.

## Decision Outcome

Chosen option:
1. M4B/MP4 Embedded Chapter Parser with manual override capabilities.
2. Virtual Multi-file Stitching: Map 1 directory to 1 `Audiobook` entity seamlessly.
3. eBook-Assisted Silence Detection: Detect silent pauses in audio and verify chapter beginnings by cross-referencing extracted speech text/phrases against linked eBook formats (`.epub`, `.pdf`, `.lit`).

### Positive Consequences

* Unifies fragmented MP3 collections into a clean single-book experience.
* Highly accurate chapter title/boundary resolution using accompanying eBook text files.
* Allows manual renaming or adjustment of faulty embedded chapters.
