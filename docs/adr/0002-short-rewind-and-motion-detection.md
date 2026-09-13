# 2. Dynamic Short Rewind and Motion Detection Window

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

To replicate Smart Audiobook Player's user experience, we need mechanisms to handle position recovery upon resuming playback after a pause, and battery-efficient motion detection for extending sleep timers.

## Decision Outcome

Chosen option:
1. Dynamic Short Rewind: Calculate rewind duration based on elapsed pause time.
2. Motion Window: Enable accelerometer sampling only during the final 2-minute grace period of an active `SmartSleepTimer`.
3. Persistent Jump History: Store the last 20 seek points in SQLite per book.

### Positive Consequences

* Prevents disorientation after resuming a book paused for hours/days.
* Preserves battery life by avoiding continuous accelerometer polling during long sleep timer runs.
* Restores jump history accurately even after OS app kills.
