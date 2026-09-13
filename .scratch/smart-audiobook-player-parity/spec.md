# Smart Audiobook Player Parity Specification

Status: `ready-for-agent`

## Problem Statement

Users accustomed to advanced audiobook playback features (such as Smart Audiobook Player on Android) find standard audio players inadequate. They suffer from lost playback positions after accidental skips, inconvenient sleep timer management when listening in bed, lack of volume/voice clarity controls tailored per book, disorganized multi-file audiobooks, and lack of chapter structure verification against eBooks.

## Solution

Build a feature-complete audiobook player adhering to the Smart Audiobook Player design philosophy. The player will feature isolated per-book playback state, smart motion-assisted sleep timers, persistent jump stacks for instant seek undo, offline-first multi-root library management with privacy-focused cover art fallbacks, dedicated Car Mode UI, extended lockscreen notification controls, 5-band voice clarity EQ, local backups, and eBook-assisted silence-detection chapter verification (`.epub`, `.pdf`, `.lit`).

## User Stories

### Phase 1: Playback & Smart Sleep Timer
1. As an audiobook listener, I want my playback speed, volume boost, and position to be independently saved per audiobook, so that switching books preserves my exact preferences.
2. As a listener using the sleep timer in bed, I want the countdown timer to reset automatically when I move or shake my phone near the end of the timer, so that I don't have to unlock my screen to extend listening.
3. As a listener who accidentally skipped forward/backward, I want a single-tap "Undo Jump" button, so that I can immediately return to my exact position prior to the skip.
4. As a listener resuming a book after several hours or days, I want the audio to automatically rewind a few seconds based on how long it was paused, so that I can quickly re-orient myself with the story.

### Phase 2: Library & Bookmarks
5. As a user with audiobooks in multiple locations, I want to add multiple root storage folders and assign content categories, so that my library scans and categorizes everything cleanly.
6. As a user finishing a book, I want its status to automatically change from `In Progress` to `Finished` when reaching >98% completion, so that my library stays organized.
7. As a privacy-conscious user, I want the app to resolve cover art locally from folder images (`cover.jpg`) or embedded ID3 metadata first, and only query online sources with my explicit confirmation per book.
8. As a listener, I want to create timestamped bookmarks containing text notes or short audio voice recordings, so that I can annotate key moments in the book.

### Phase 3: UI, Media Controls & Backups
9. As a driver, I want an in-app Car Mode with oversized touch controls and simple swipe gestures, so that I can safely control playback while driving.
10. As a listener, I want lockscreen notification controls to include explicit `-10s` / `+30s` seek buttons, a quick bookmark button, and a sleep timer extension button.
11. As a listener dealing with low-quality narration audio, I want a 5-band graphic equalizer with a "Voice Clarity" boost per book, so that spoken words are distinct and intelligible.
12. As a user switching devices or reinstalling the app, I want to export and import my complete library status, progress, and bookmarks to a local JSON/ZIP backup file.

### Phase 4: Formats, Chapters & eBook Verification
13. As a listener with M4B audiobooks, I want embedded chapter tables of contents to be automatically parsed and navigable, with the ability to manually rename chapters if needed.
14. As a listener with multi-file MP3 folders, I want the player to stitch the folder into a single virtual audiobook seamlessly.
15. As a listener with a single long MP3 file without chapters, I want silence detection to propose chapter splits, and I want to align the detected chapters with an attached eBook (`.epub`, `.pdf`, `.lit`) by matching the first sentences of each section.

## Implementation Decisions

- **State Persistence**: Utilize `sqflite` to store `Audiobook`, `PlaybackState`, `Bookmark`, and `JumpHistory` entities with per-book isolation.
- **Sleep Timer & Motion Sensing**: Encapsulate timer logic in a `SmartSleepTimerService` that listens to `sensors_plus` (accelerometer) only during the final 2-minute warning window.
- **Dynamic Short Rewind**: Implement a logarithmic rewind calculator upon resuming: 0s if paused <5 min, 10s if paused <1 hour, up to 30s if paused >8 hours.
- **Audio Engine Extensions**: Extend `just_audio` and `just_audio_background` to support custom background media actions and 5-band EQ filters.
- **eBook Text Alignment**: Implement a text parsing service for `.epub`, `.pdf`, and `.lit` formats that compares opening sentences of silence-detected chapters against eBook headings/paragraphs.

## Testing Decisions

- Tests will focus on domain service boundaries and state transitions rather than UI rendering.
- `SmartSleepTimerService` tests will verify timer countdown, motion event trigger, and playback pause dispatching.
- `ShortRewindCalculator` unit tests will verify exact rewind calculations across various pause duration deltas.
- `JumpHistory` repository tests will verify LIFO stack behavior, max-limit trimming (20 items), and persistent restoration across mock DB restarts.
- `CoverArtResolver` unit tests will verify strict adherence to resolution priority (Local file -> Embedded ID3 -> Fallback/Online gate).

## Out of Scope

- Cloud sync via Google Drive / WebDAV (deferred to a future release after local backup is established).
- DRM-protected proprietary formats (e.g., AAX with active DRM).

## Further Notes

All vocabulary adheres to `CONTEXT.md` and architecture decisions recorded in `docs/adr/0001` through `docs/adr/0005`.
