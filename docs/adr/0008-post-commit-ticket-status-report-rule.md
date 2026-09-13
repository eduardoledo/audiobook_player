# 8. Post-Commit Ticket Status Report Rule

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

To maintain complete clarity on progress across active sprints and architectural epics, the workflow should automatically present the remaining pending tickets immediately after a ticket is committed and pushed.

## Decision Outcome

Chosen option:
Directly following user-approved `git commit` and `git push` operations for any ticket:
1. Scan `.scratch/*/issues/`.
2. Display a clear Markdown status table showing all remaining `ready-for-agent` tickets, highlighting which ones are unblocked and ready for immediate execution on the frontier.

### Positive Consequences

* Continuous visibility of pending work without requiring manual user queries.
* Seamless transition to the next frontier ticket.
