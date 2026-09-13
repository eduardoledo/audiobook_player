# 22. Nested Set Category Hierarchy & Multi-Depth Book Placement

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

To support flexible and deeply nested library organization (Authors, Universes, Sagas, Sub-series, Eras) without hardcoded level structures, category hierarchies need to be queries efficiently and allow books to be attached as children at any depth level of the tree.

## Decision Outcome

Chosen option:
1. **Nested Set Representation**: Category hierarchies are persisted in a dedicated SQLite `categories` table using the Nested Set Model (`id`, `name`, `lft`, `rgt`, `depth`, `parent_id`, `path_prefix`). Subtree queries use `WHERE lft BETWEEN parent.lft AND parent.rgt`.
2. **Multi-Depth Leaf & Intermediate Placement**: Books (`audiobooks`, `ebooks`) store a foreign `category_id` linking them directly to a category node at any depth level of the tree. Standalone books can hang directly off an Author node, while series books attach to deeper Saga or Era nodes.
3. **Automated Scanner Tree Building with Disambiguation Prompt**: `AudiobookScanner` builds and updates the `categories` Nested Set during library scanning based on directory path segments. If ambiguities or collisions occur, the user is prompted to confirm the layout.

### Positive Consequences

* Single SQL query retrieves entire category subtrees with depth and ordering without recursive CTEs.
* Allows arbitrary nesting depth for complex universes (e.g. Cosmere -> Mistborn -> Era 1 -> Books).
* Flexible attachment enables books to exist at parent category levels alongside sub-categories.
