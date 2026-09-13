# 01: Path Metadata Parser & Scanner Integration

**What to build:**
Refactor `AudiobookScanner` to delegate all path tokenization, positional segment mapping (`SegmentPathMapping`), and disc/part/era folder classifications to the newly created `PathMetadataParser` service.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `AudiobookScanner` delegates folder classification to `PathMetadataParser.looksLikeEraFolder`, `looksLikeDiscPartFolder`, and `partOrderFromFolderName`
- [ ] `AudiobookScanner` uses `PathMetadataParser.parsePath()` for extracting author, universe, saga, and title
- [ ] Support for passing `SegmentPathMapping` in scanner configuration
- [ ] All existing scanner integration tests pass cleanly
