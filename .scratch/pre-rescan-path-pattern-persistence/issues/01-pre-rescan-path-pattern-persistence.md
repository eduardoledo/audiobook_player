# 01: Pre-Rescan Path Pattern Persistence

**What to build:**
Ensure `PathStructureSelectorDialog._saveRule()` awaits `LibraryStorage.savePathPatternRule(rule)` before popping `true`, ensuring `HomeDrawer` callers trigger `rescanAll()` with updated rules. Add unit tests for dialog rule saving flow.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] Verify `PathStructureSelectorDialog._saveRule()` awaits `_storage.savePathPatternRule`
- [ ] Add unit test in `test/path_pattern_rule_test.dart` verifying rule persistence before rescan trigger
- [ ] Verify `flutter analyze` passes with 0 issues
