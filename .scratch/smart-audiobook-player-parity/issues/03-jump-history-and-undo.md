# 03: Jump History & Instant Undo Seek

**What to build:**
A persistent `JumpHistory` LIFO stack (max 20 entries) per book recording position snapshots prior to manual seeks, fast-forwards, or chapter skips, paired with a single-tap "Undo Jump" UI button.

**Blocked by:** 01-per-book-state-and-short-rewind

**Status:** ready-for-agent

- [ ] `JumpHistory` repository storing timestamp jumps in SQLite per `Audiobook`
- [ ] Manual seek, chapter skip, or scrub pushes previous position onto the jump stack
- [ ] "Undo Jump" button pops the stack and restores playback position instantly
- [ ] Unit tests for LIFO stack eviction limits (20 items max) and persistence
