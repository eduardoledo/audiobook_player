Status: ready-for-agent

# Spec: Main Library Hybrid View (Grid & Accordion Nested Set List) with View Persistence

## Problem Statement

Users navigating their audiobook collection on the main home screen need flexible visual layouts based on context and device size. Some users prefer a high-density visual grid showing large cover art, while others prefer a detailed horizontal list with multi-level category hierarchy (Authors, Sagas, Sub-series, Eras). Additionally, switching between views should persist seamlessly across app restarts, and the list hierarchy must strictly reflect the SQLite Nested Set category structure without falling back to string-parsing heuristics.

## Solution

Implement a dynamic hybrid view switcher on the home screen toolbar (`AppBar`). Users can toggle between **Grid View** and **Accordion List View**. In List mode, the collection is rendered as a collapsible tree accordion where every hierarchy level maps 1:1 to a `CategoryNode` in the SQLite `categories` Nested Set table. Books are grouped strictly by their `category_id` (with uncategorized books hanging under a synthetic "Sin categoría" root node). The user's active view mode preference (`'grid'` vs `'list'`) is persisted in the SQLite `settings` key-value table.

## User Stories

1. As an audiobook listener, I want to toggle between Grid View and List View from the top AppBar, so that I can choose the visual format that best fits my current task.
2. As an audiobook listener, I want my selected view mode (Grid or List) to persist across app restarts, so that I do not have to reselect my preferred layout every time I open the app.
3. As a listener with a large, deeply nested collection, I want the List View to display collapsible category headers (Authors, Sagas, Sub-series) with 16dp progressive indentation, so that I can easily navigate complex multi-level universes.
4. As a listener, I want category headers in List View to display the total book count, cumulative audio duration, and a continuous playback button, so that I can manage and play entire sagas with a single tap.
5. As a listener, I want my expand/collapse state for each category node to be remembered during my session, so that the tree structure remains stable while browsing.
6. As a listener, I want uncategorized books without a valid `category_id` to be grouped under a "Sin categoría" root node in List View, so that no books are hidden or lost.
7. As a listener, I want the search bar to match both category names and book titles/authors, auto-expanding the category path to matching books, so that I can quickly locate content within deep hierarchies.
8. As a listener, I want tap interactions on books to open the player/details screen and long-press interactions to trigger a contextual menu (mark read, add to playlist, delete), so that I can perform management actions efficiently.

## Implementation Decisions

- **View Mode Switching**: Introduce an `AppBar` toggle action emitting a view mode change event to the main screen state manager (`HomeCubit`).
- **SQLite Settings Persistence**: Store the view preference under key `'main_library_view_mode'` with string values `'list'` or `'grid'` in the SQLite `settings` table via `LibraryStorage`. Default to `'list'` on first launch. Load preference in `HomeCubit.init()`.
- **Strict 1:1 Nested Set Rendering**: List hierarchy is built exclusively from `CategoryNode` records fetched from SQLite `categories` ordered by `lft ASC`. Runtime file path string parsing is strictly prohibited for level construction.
- **Uncategorized Books Handling**: Books with null or invalid `category_id` are grouped under a synthetic `CategoryNode` labeled "Sin categoría".
- **Visual Styling of Nodes**: Accordion levels feature 16dp progressive horizontal indentation per depth level. Headers display category type icons (Author, Saga, Sub-series), bold typography, contrast background, book count, total audio duration, and continuous play action.
- **Search & Filter Behavior**: Searching evaluates category names and book metadata. Matching a category node reveals all child books; matching a book node expands its ancestral path in the Nested Set.

## Testing Decisions

- **Testing Principles**: Tests focus strictly on observable state emissions and user-visible behavior across seams, avoiding internal private widget implementation details.
- **Primary Seam (Integration)**: `HomeCubit` integration tests verifying state transitions when loading `main_library_view_mode` from SQLite settings, toggling view modes, and building the category tree strictly from `LibraryStorage.getAllCategories()`.
- **Secondary Seam (UI / Widget)**: `HomeScreen` widget tests verifying that tapping the AppBar toggle updates the displayed layout between Grid and Accordion List, and that expanding/collapsing category tiles behaves correctly.
- **Prior Art**: Refer to existing `test/bloc/home_categories_integration_test.dart` and `test/home_search_bar_test.dart` for BLoC and widget testing patterns in this repository.

## Out of Scope

- Modifying the underlying SQLite `categories` Nested Set schema or scanner logic (covered by ADR 0022).
- Manual drag-and-drop category reordering.
- Grid View multi-level folder hierarchy (Grid View displays direct cover tiles without nested folder accordions).

## Further Notes

- Aligns directly with **ADR 0022** (Nested Set Category Hierarchy), **ADR 0023** (Nested Set UI Tree Rendering), and **ADR 0024** (Hybrid Main Book List Layout & View Persistence).
