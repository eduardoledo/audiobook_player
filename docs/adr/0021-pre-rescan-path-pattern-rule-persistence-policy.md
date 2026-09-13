# 21. Pre-Rescan Path Pattern Rule Persistence Policy

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

When users edit path structure roles in `PathStructureSelectorDialog` and click "Guardar Patrón", the updated rule must be fully persisted to SQLite storage (`savePathPatternRule`) before the dialog dismisses and triggers `rescanAll()`. Previously, if a race condition occurred between asynchronous persistence and scan start, `AudiobookScanner` could run against stale pattern rules.

## Decision Outcome

Chosen option:
1. **Atomic Pre-Rescan Persistence**: `PathStructureSelectorDialog._saveRule()` awaits `LibraryStorage.savePathPatternRule(rule)` completely to ensure disk/SQLite commit before notifying listeners (`onRuleSaved`) and popping `true`.
2. **Rescan Guarantee**: `HomeDrawer` and other callers only initiate `unawaited(homeCubit.rescanAll())` after `showDialog<bool>` returns `true`, guaranteeing `AudiobookScanner` reads the updated rule directly from storage.

### Positive Consequences

* Prevents scan race conditions against outdated path segment rules.
* Guarantees database consistency before initiating asynchronous library rescans.
