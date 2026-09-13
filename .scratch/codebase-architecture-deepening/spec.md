# Codebase Architecture Deepening Specification

Status: `ready-for-agent`

## Problem Statement

As the audiobook player grew in capabilities, key modules became shallow or monolithic. `audiobook_scanner.dart` (1,800+ lines) tangled file system traversal with regex path pattern tokenization and era/part classification, making unit testing impossible without mock file systems. Similarly, chapter structure detection and eBook alignment logic were fragmented across 5 shallow modules requiring caller orchestration.

## Solution

Deepen the codebase architecture at two critical seams:
1. Extract `PathMetadataParser` from `audiobook_scanner.dart` into a pure, IO-free domain service supporting positional segment mapping, custom regex rules, and folder classification.
2. Unify audio chapter analysis, M4B TOC parsing, silence candidate detection, and eBook phrase alignment under a single deep `ChapterDetector` module interface.

## User Stories

1. As a maintainer/agent, I want path metadata parsing to be decoupled from IO and isolates, so that I can unit-test folder rules and positional mappings cleanly with pure string inputs.
2. As a user, I want to map specific path segments (e.g. Segment 0 = Author, Segment 1 = Universe, Segment 2 = Saga) to my library folders, so that non-standard folder structures are correctly categorized.
3. As a developer, I want a single `detectChapters(audioPath, ebookPath)` interface method, so that complex silence detection, ASR transcription, and eBook alignment happen transparently behind a clean seam.

## Implementation Decisions

- **PathMetadataParser**: Pure domain service in `lib/services/path_metadata_parser.dart`. Encapsulates `looksLikeEraFolder`, `looksLikeDiscPartFolder`, `partOrderFromFolderName`, and `SegmentPathMapping`.
- **ChapterDetector**: Unified entry point in `lib/services/chapter_detector.dart`. Accepts `ChapterDetectorOptions` and handles fallback gracefully to silence-based auto-numbering if eBook alignment fails.

## Testing Decisions

- Tests will focus on interface behavior at the new seams.
- `PathMetadataParser` unit tests in `test/services/path_metadata_parser_test.dart` verify default folder tokenization, manual segment mappings, and disc/part classifications.
- `ChapterDetector` unit tests in `test/services/chapter_detector_test.dart` verify deep single-entry execution and fallback strategies.

## Out of Scope

- Modifying the underlying Flutter UI layout components.

## Further Notes

Respects ADR 0005 and ADR 0006.
