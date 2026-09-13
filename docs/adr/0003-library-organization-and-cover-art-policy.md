# 3. Library Roots, Automatic Status Transitions, and Cover Art Fallback Policy

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Smart Audiobook Player organizes large libraries using multiple root directories, automatic lifecycle tagging (New/In Progress/Finished), rich bookmarks, and cover art retrieval. We need a clear policy regarding library scanning, status transitions, and offline-first cover art fetching with optional online fallbacks.

## Decision Outcome

Chosen option:
1. Multi-root Folders: Support multiple root directories with category tagging.
2. Auto Status: Automatically transition status (`New` -> `In Progress` at start, -> `Finished` at >98% completion).
3. Cover Art Pipeline:
   - Priority 1: Local file (`cover.jpg` / `cover.png`).
   - Priority 2: Embedded ID3 / MP4 artwork.
   - Priority 3: Online search (requires explicit user confirmation).
   - Priority 4: Generic asset fallback.
4. Rich Bookmarks: Support timestamped text notes and short audio voice recordings.

### Positive Consequences

* Ensures privacy and zero unconsented network traffic by default.
* Fully automated status updates reduce manual organization burden.
* Multi-root support matches power user storage setups.
