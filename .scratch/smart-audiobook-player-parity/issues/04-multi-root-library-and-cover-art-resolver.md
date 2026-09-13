# 04: Multi-Root Library & Privacy-First Cover Art Resolver

**What to build:**
Multi-root directory scanning with category tags, automatic book status lifecycle transitions (`New` -> `In Progress` -> `Finished`), and a cover art resolution pipeline prioritizing local files and embedded metadata before prompting for optional online fetches.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] Support registering multiple root folders with category labels
- [x] Automatic status update (`New` on scan, `In Progress` on play start, `Finished` at >98% progress)
- [x] `CoverArtResolver` enforcing resolution order: `cover.jpg/png` -> ID3/MP4 metadata -> User prompt for online search -> Asset placeholder
- [x] Unit tests for status transition logic and cover art priority fallbacks
