# 12. Copyable Command Snippets for Tickets Rule

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Markdown file links (`file:///...`) open files in the editor, but do NOT complete text in the user's chat prompt. In this UI, `@` mentions do not convert to interactive pills inside Markdown table cells unless rendered as ready-to-copy code blocks. To provide an effortless 1-click experience to run `/tdd` or `/implement` commands, every pending ticket must present ready-to-click/copy command snippets in code blocks.

## Decision Outcome

Chosen option:
Render ticket command lines as explicit code blocks (e.g. `/tdd .scratch/smart-audiobook-player-parity/issues/04-multi-root-library-and-cover-art-resolver.md`) alongside standard file links.

### Positive Consequences

* One-click copy/run of the full `/tdd` or `/implement` command directly from the chat report.
