# 02: Chapter Detector & Alignment Integration

**What to build:**
Implement full internal pipeline inside `ChapterDetector.detectChapters()` by combining M4B TOC parsing, `SilenceCandidateFinder`, and `KeywordChapterMatcher` / eBook phrase matching, presenting a single deep interface to callers.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] `ChapterDetector` checks for embedded M4B TOC chapters first
- [x] If no TOC exists, `ChapterDetector` triggers `SilenceCandidateFinder`
- [x] If an eBook path is provided, `ChapterDetector` matches detected silence breaks against eBook section headings
- [x] Automatic fallback to numbered chapters if eBook text alignment is inconclusive
- [x] Unit & integration tests for full `detectChapters` pipeline
