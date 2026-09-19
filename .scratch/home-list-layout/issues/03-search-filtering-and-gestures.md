Status: ready-for-agent

# 03: Search Filtering with Ancestral Auto-Expansion & Touch Gestures

**What to build:** Searching in the top search bar matches both category names and book titles/authors. When a category matches, all its child books are displayed; when a book matches, its ancestral Nested Set category path auto-expands. Tap and long-press interactions on accordion items trigger player navigation and context menus smoothly.

**Blocked by:** 02: Strict Nested Set Accordion List View & Uncategorized Node

## Acceptance Criteria

- [ ] Searching by text evaluates both `CategoryNode.name` and `Audiobook` title/author.
- [ ] Category match displays the category node with all its children expanded.
- [ ] Book match auto-expands all parent category nodes along its Nested Set ancestral path.
- [ ] Tapping a book item opens the audio player/details view.
- [ ] Long-pressing a book item displays a contextual menu (mark read, add to playlist, delete).
- [ ] Integration & widget tests verify search filtering and expansion behavior.
