# 1. Per-Book Playback State and Smart Sleep Timer

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Smart Audiobook Player (SAP) provides a tailored listening experience where each audiobook retains its own speed, volume, and equalizer parameters. Furthermore, its signature Smart Sleep Timer utilizes physical motion (accelerometer) to gracefully extend playback. We need to decide how state management, timer events, and position history should be architected in the application.

## Decision Drivers

* Users listen to multiple audiobooks with different narration styles and volumes.
* Accidental seeks or losses of playback position frustrate users.
* Hands-free sleep timer reset is critical when listening in bed.

## Considered Options

1. Global player state shared across all audiobooks with manual sleep timer reset only.
2. Per-book isolated state persisted in SQLite, dedicated `SmartSleepTimer` service with accelerometer detection, and a `JumpHistory` stack for instant undo.

## Decision Outcome

Chosen option: Option 2.

### Positive Consequences

* Seamless switching between audiobooks preserves user preferences (speed/gain/position).
* Motion-based sleep timer reset eliminates the need to unlock or look at the phone screen to extend listening.
* `JumpHistory` provides safety against accidental position skips.

### Negative Consequences

* Higher complexity in database schema and sensor management across platforms.
