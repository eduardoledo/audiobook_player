# 4. Car Mode UI, Extended Media Notification Actions, and Local Backups

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

Audiobook listeners frequently play content while driving or via lockscreen controls, requiring low-distraction interfaces and rapid actions (seek, bookmark, sleep timer extension). Furthermore, protecting listening progress across app installs or device switches is essential.

## Decision Outcome

Chosen option:
1. In-App Car Mode: Dedicated high-contrast interface with enlarged touch buttons + gesture support, paired with Android Auto / CarPlay integration.
2. Extended Notification Actions: Custom media notification action buttons (`-10s`, `+30s`, `Add Bookmark`, `Extend Sleep`).
3. 5-Band Equalizer: Voice clarity pre-set & gain boost per book.
4. Local Auto-Backup: Offline JSON/ZIP export for database position snapshots, deferring cloud sync to subsequent phases.

### Positive Consequences

* Safe and accessible controls during driving.
* Quick actions available directly on lockscreens without unlocking the device.
* Complete data sovereignty via local, human-readable offline backups.
