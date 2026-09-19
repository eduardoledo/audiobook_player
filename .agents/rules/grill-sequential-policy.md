---
trigger: always_on
---

# Sequential Grilling Policy

When running grilling sessions (`/grill-me`, `/grill-with-docs`, or using the `grilling` skill):

1. **Sequential Questions Only**: NEVER output multiple questions in a single turn. Always present exactly ONE question per turn.
2. **Interactive Option Selection**: ALWAYS use the `ask_question` interactive tool for every question so the user can directly select from the listed options via UI buttons.
3. **Wait for Answer**: Present the single question with options, set your recommended option as first, and wait for user selection before proceeding to the next question.
4. **Adaptive Frontier**: Recompute the design tree frontier after each answer to formulate the next sequential question.
