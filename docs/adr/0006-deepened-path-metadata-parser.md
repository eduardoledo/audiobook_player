# 6. Deepened Path Metadata Parser Seam & User Segment Mapping

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

`AudiobookScanner` became a 1,800+ line monolith because path tokenization, folder classification (eras, discs, parts), regex rule evaluation, and positional segment mapping were tangled with file system traversal and isolate messaging.

## Decision Outcome

Chosen option:
1. Extract `PathMetadataParser` into a dedicated pure domain module (`lib/services/path_metadata_parser.dart`).
2. Encapsulate folder classification (`looksLikeEraFolder`, `looksLikeDiscPartFolder`, `partOrderFromFolderName`) within `PathMetadataParser`.
3. Support manual user-selected segment mapping (Segment Path Mapper) allowing users to map path segments (e.g., segment 0 = Author, 1 = Universe) alongside custom regex rules.

### Positive Consequences

* Shrinks `AudiobookScanner` by hundreds of lines.
* Enables IO-free unit testing of complex path hierarchy extraction and manual segment mapping.
* High locality for path parsing rules and maintainability.
