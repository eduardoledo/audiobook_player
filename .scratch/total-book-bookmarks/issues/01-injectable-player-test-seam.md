# 01: Injectable PlayerScreen & Playback Engine Test Seam (Prefactor)

**What to build:** Enable deterministic end-to-end widget and persistence testing of the player view, playback service, and SQLite storage together without requiring platform audio hardware channels or modifying existing production call sites.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] The player screen accepts optional injected playback service and library storage instances via constructor parameters while defaulting to the service locator for existing callers (aligned with ADR 0020).
- [x] The playback service isolates its low-level audio engine and audio-file duration probing behind an injectable boundary so playback position, active track index, duration streams, play/pause state, and seek operations can be driven deterministically in tests without platform channels.
- [x] A baseline integration test mounts the player screen against the real playback service and real SQLite FFI storage, verifying `Audiobook` initialization, playback state rendering, and `Bookmark` creation/listing with zero behavior changes.
- [x] Static analysis (`flutter analyze lib/`) and all existing tests pass with 0 errors and 0 warnings (ADR 0014).
