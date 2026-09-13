# 01: Hierarchy Level Deduplication

**What to build:**
Implement case-insensitive string deduplication across hierarchy levels in `PathMetadataParser.parsePath` (setting lower matching levels to `null`), and update `AudiobookScanner` to clear duplicate fields in SQLite on rescan.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Implement hierarchy deduplication logic in `PathMetadataParser.parsePath`
- [ ] Auto-clear duplicate hierarchy fields in SQLite during library rescans
- [ ] Add unit tests in `test/services/path_metadata_parser_test.dart`
- [ ] Verify `flutter analyze` passes with 0 issues
