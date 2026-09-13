# 08: Multi-File Stitching, M4B TOC & eBook-Assisted Chapter Verification

**What to build:**
Seamless stitching of multi-file MP3 directories into single virtual audiobooks, parsing M4B embedded TOC chapters with manual override support, silence detection chapter proposals, and verification of detected chapter boundaries against linked eBook files (`.epub`, `.pdf`, `.lit`).

**Blocked by:** 01-per-book-state-and-short-rewind

**Status:** resolved

- [x] Directory scanner maps multi-file MP3 folders into a unified continuous `Audiobook` entity
- [x] Parser extracts embedded TOC chapter titles and timestamps from M4B/MP4 files with manual edit support
- [x] Silence-detection algorithm proposes candidate chapter breaks on long audio files
- [x] eBook parser (`.epub`, `.pdf`, `.lit`) matches opening sentences following silence breaks to confirm chapter titles
- [x] Unit tests for eBook sentence matching and chapter stitching logic
