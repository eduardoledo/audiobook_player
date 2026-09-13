# 11. Slash Command Mention Syntax in Ticket Reports Rule

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

In the Antigravity IDE UI, rendering items using symbol mention syntax (e.g. `@[.scratch/smart-audiobook-player-parity/issues/04-multi-root-library-and-cover-art-resolver.md]`) or `file:///` markdown links allows users to click or insert the path directly into the chat prompt. To ensure instant 1-click completion in chat, tickets should be presented as interactive `@-mentions` or file links.

## Decision Outcome

Chosen option:
Render ticket paths in report tables using `@[filepath]` mention syntax (or clickable markdown file links `[path](file:///path)`) so clicking them immediately inserts/completes the path in the chat input.

### Positive Consequences

* Instant 1-click completion of ticket paths into chat commands.
