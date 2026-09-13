# 01: Consolidate Extractors in PathMetadataParser

**What to build:**
Move `publishYearFromPath`, `narratorFromPath`, `orderTokenFromSegment`, `stripPublishYearFromTitle`, and `stripNarratorFromTitle` into `PathMetadataParser`. Update `parsePath` to extract year/narrator/order fields and return sanitized titles. Delegate methods from `AudiobookScanner`.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Move publication year, narrator, and order token extractors to `PathMetadataParser`
- [ ] Implement title string sanitization in `PathMetadataParser.parsePath`
- [ ] Delegate static methods in `AudiobookScanner` to `PathMetadataParser`
- [ ] Add comprehensive unit tests in `test/services/path_metadata_parser_test.dart`
- [ ] Ensure `flutter analyze` passes with 0 issues
