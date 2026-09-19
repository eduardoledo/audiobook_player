Status: ready-for-agent

# 02: Strict Nested Set Accordion List View & Uncategorized Node

**What to build:** In List mode, the main library collection renders as a multi-level collapsible accordion tree built strictly 1:1 from SQLite `categories` (`lft ASC`). Each category level features 16dp progressive indentation, category type icon, bold title, book count, total audio duration, and a continuous playback button. Books without a `category_id` group under a synthetic "Sin categoría" root node.

**Blocked by:** 01: View Mode State & SQLite Settings Persistence

## Acceptance Criteria

- [ ] List View hierarchy is rendered strictly from SQLite `categories` (`lft ASC`, `depth`, `parent_id`), omitting runtime string/path regex parsing.
- [ ] Each category level displays 16dp progressive indentation per depth level.
- [ ] Category headers display icon by type (Author, Saga, Sub-series), bold name, book count badge, total audio duration, and a "Play Category" continuous playback button.
- [ ] Books with null or invalid `category_id` render under a synthetic root category titled "Sin categoría".
- [ ] Expand and collapse state for each category node is maintained in memory during the user's session.
- [ ] Widget tests in `test/widgets/` verify category accordion expanding/collapsing and rendering.
