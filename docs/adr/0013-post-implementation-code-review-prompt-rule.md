# 13. Post-Implementation Code Review Prompt Rule

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

After finishing any ticket implementation, running tests, and executing git commit/push, the user wants the option to immediately run a dual-axis code review (`/code-review` covering repo standards and spec alignment) before picking the next ticket.

## Decision Outcome

Chosen option:
Directly after completing any ticket implementation and reporting progress, prompt the user with `ask_question` asking if they would like to trigger a `/code-review` session on the recent changes.

### Positive Consequences

* Continuous quality assurance and adherence to project coding standards.
* Catches regressions or spec mismatches before proceeding to downstream tickets.
