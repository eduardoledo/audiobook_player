# Spec: Pre-Rescan Path Pattern Persistence

Status: ready-for-agent

## Problem Statement

When path structure roles are updated in `PathStructureSelectorDialog`, the updated `PathPatternRule` must be persisted to SQLite before `HomeCubit.rescanAll()` is invoked.

## Solution

Ensure `PathStructureSelectorDialog._saveRule()` awaits `LibraryStorage.savePathPatternRule` completely, triggers `onRuleSaved`, and returns `true`. Verify callers in `HomeDrawer` invoke `rescanAll()` only when `true` is returned.

## User Stories

1. As a user modifying folder structure roles, I want my selection saved immediately to SQLite before scanning starts so that the scan uses my new rule.

## Implementation Decisions

- **Dialog Persistence**: `_saveRule()` awaits `_storage.savePathPatternRule(rule)` before popping `true`.
- **ADR Alignment**: Guided by ADR 0021.
