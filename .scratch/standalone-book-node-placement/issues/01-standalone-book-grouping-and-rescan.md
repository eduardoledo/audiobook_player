# 01: Standalone Book Grouping & Rescan

**What to build:**
Ensure 2-segment paths (`Author/BookTitle`) assign `saga = null` and `universe = null` in `PathMetadataParser` and `AudiobookScanner`, update UI tree rendering to place `saga == null` books directly under the Author node, and auto-clear `saga` in SQLite on rescan.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Ensure 2-segment paths assign `saga = null` and `universe = null` in `PathMetadataParser`
- [ ] Update `AudiobookScanner` to clear `saga` in SQLite on rescan for 2-segment paths
- [ ] Verify library UI tree places `saga == null` items directly under Author node
- [ ] Add unit tests in `test/services/path_metadata_parser_test.dart`
- [ ] Verify `flutter analyze` passes with 0 issues
