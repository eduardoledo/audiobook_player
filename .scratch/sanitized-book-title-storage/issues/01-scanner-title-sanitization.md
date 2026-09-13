# 01: Scanner Title Sanitization

**What to build:**
Update `AudiobookScanner` to sanitize `bookTitle` by stripping detected year brackets and narrator parentheses before creating `Audiobook` instances, preserving explicit `book.metadata.json` titles.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Strip publication year and narrator tokens from `bookTitle` in `AudiobookScanner`
- [ ] Preserve explicit titles in `book.metadata.json`
- [ ] Auto-sanitize existing database records during library rescans
- [ ] Add unit tests in `test/audiobook_scanner_test.dart`
- [ ] Verify `flutter analyze` passes with 0 issues
