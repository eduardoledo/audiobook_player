# 14. Zero Current Problems Quality Invariant

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

To prevent technical debt and broken builds, code modified by implementation tasks or refactoring must strictly pass static analysis with zero errors and zero warnings.

## Decision Outcome

Chosen option:
- Mandate running `flutter analyze lib/` to verify zero analyzer problems (`@current_problems` empty) before declaring any implementation finished or prompting for git commit/push.

### Positive Consequences

* Ensures 100% build validity and zero linter regressions.
