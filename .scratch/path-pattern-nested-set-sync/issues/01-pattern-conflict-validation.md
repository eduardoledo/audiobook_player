# Ticket 01: Pattern Conflict Validation & User Choice Dialog

## Status: Ready

## Description
Implement the 2-stage conflict validation flow when saving a pattern rule in `PathStructureSelectorDialog`.

## Acceptance Criteria
- Validate overlapping scan root paths (subpath / parent path overlap).
- Validate category node role collisions at matching hierarchy depths.
- Present conflict resolution dialog when collisions occur with "Mantener Patrón Anterior" and "Reemplazar con Nuevo Patrón" options.
- Prevent invalid pattern saves when user selects "Mantener Patrón Anterior".
