# 10. Plain Text Absolute File Paths in Ticket Reports Rule

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

When markdown file links (`[text](file:///path)`) are rendered in the agent chat interface, clicking them opens the file directly in the editor, but does NOT insert the path string into the chat input area for `/tdd` or `/implement` commands. To allow users to copy/paste or click to complete the path in the input box, absolute file paths must be rendered as raw text or inline code blocks.

## Decision Outcome

Chosen option:
Always include the exact absolute filepath in raw text / inline code (e.g. `.scratch/smart-audiobook-player-parity/issues/04-multi-root-library-and-cover-art-resolver.md`) in ticket lists so users can copy/click the exact path string directly into their command input.

### Positive Consequences

* Allows immediate autocomplete/paste of ticket filepaths directly into chat commands (`/tdd <path>`, `/implement <path>`).
