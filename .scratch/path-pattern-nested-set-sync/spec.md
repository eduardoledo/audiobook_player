# Active Path Pattern to Nested Set Synchronization & Conflict Resolution Specification

## 1. Overview
When saving a directory structure pattern rule via `PathStructureSelectorDialog`, the application must perform an active hierarchy synchronization with the SQLite `categories` Nested Set table. It scans all directories under registered scan roots according to saved rules, creates/updates `CategoryNode` records, recalculates global Nested Set bounds (`lft`, `rgt`, `depth`, `path_prefix`), assigns audiobooks to their `category_id`, and enforces a 2-stage conflict validation flow.

---

## 2. Requirements & Functional Specifications

### 2.1 Pattern Rule Persistence & Active Sync Trigger
- Upon tapping **"Guardar Patrón"** in `PathStructureSelectorDialog`:
  1. Evaluate pattern conflicts before persisting.
  2. If clean (or user selects "Reemplazar"):
     - Save `PathPatternRule` to `LibraryStorage`.
     - Trigger `rebuildNestedSetFromPatterns()` in `LibraryStorage` / `HomeCubit`.
     - Perform global filesystem scan under registered scan paths.
     - Generate `CategoryNode` hierarchy with relative path bindings.
     - Recalculate `lft`, `rgt`, `depth`, `parent_id`, and `path_prefix` for all nodes in SQLite `categories`.
     - Update `category_id` on all stored `Audiobook` records.

### 2.2 Pattern Conflict Detection Pipeline
- **Stage 1: Overlapping Path Validation**:
  - Check if target `rootPath` is equal to, a child of, or a parent of any existing `PathPatternRule` root path.
- **Stage 2: Category Collisions**:
  - Check if target pattern roles produce conflicting category node roles or duplicate sibling path prefixes at the same depth.
- **Conflict Handling Dialog**:
  - If a conflict occurs, display an interactive modal:
    - **Title**: *"Conflicto de Patrón Detectado"*
    - **Options**:
      1. **Mantener Patrón Anterior**: Aborts save operation, leaves existing rules and Nested Set untouched.
      2. **Reemplazar con Nuevo Patrón**: Overwrites conflicting rule and executes full global Nested Set recalculation taking all valid active pattern rules into account.

### 2.3 Nested Set Recalculation Algorithm
1. Traverse category tree depth-first ordered by `name ASC`.
2. Assign left (`lft`) and right (`rgt`) integers sequentially starting from 1.
3. Compute `depth` (root children = depth 0 or 1 per hierarchy mapping).
4. Persist updated `CategoryNode` records to SQLite `categories`.
5. Associate each `Audiobook` record to its deepest matching `category_id` based on its directory path relative to scan roots.

---

## 3. Data Schema & Models

### 3.1 SQLite `categories` Table
```sql
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  lft INTEGER NOT NULL,
  rgt INTEGER NOT NULL,
  depth INTEGER NOT NULL,
  parent_id INTEGER,
  path_prefix TEXT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE CASCADE
);
```

---

## 4. Acceptance Criteria
1. Tapping "Guardar Patrón" triggers instant synchronization of the `categories` Nested Set table without requiring a full manual media rescan.
2. Saving a pattern with an overlapping root or colliding roles presents the conflict resolution modal.
3. Choosing "Mantener Patrón Anterior" preserves previous pattern rules and category nodes.
4. Choosing "Reemplazar con Nuevo Patrón" overwrites the conflicting rule and correctly recalculates all `lft`/`rgt`/`depth` values across all remaining active pattern rules.
5. All unit, BLoC, integration, and UI tests pass with 0 analyzer errors or warnings.
