# Context & Glossary

This document defines the canonical domain vocabulary for the Audiobook Player project. All code, documentation, and agent interactions must adhere strictly to these definitions.

---

## Core Entities

### Audiobook
A logical entity representing a single audio book, which may consist of one or more physical audio files (chapters or parts) stored in a structured directory or container format.

### Book Status
The classification of an `Audiobook` within the library lifecycle:
- **New**: Unopened/unstarted book.
- **In Progress**: Book currently being listened to, with saved position history.
- **Finished**: Book that has been completed by the user.

### Bookmark
A user-created or system-generated marker at a specific timestamp within an `Audiobook`, optionally containing a title, text note, or auto-recorded audio snippet.

---

## Playback & Audio Control

### Playback State
The isolated runtime parameters associated with a specific `Audiobook`:
- **Current Position**: Timestamp in milliseconds.
- **Playback Speed**: Rate multiplier (e.g., 0.5x to 3.0x) persisted per book.
- **Volume Gain / Voice Boost**: Amplification or equalizer settings specialized for speech clarity.

### Smart Sleep Timer
An inactivity countdown timer that automatically pauses audio playback. It supports automatic reset upon detecting physical movement via accelerometer sensor inputs (shake-to-extend).

### Jump History
A stack of manual position changes (e.g., seek, fast-forward, chapter skip) allowing immediate "Undo Jump" restoration if the user accidentally loses their place.

---

## Advanced Playback Controls

### Short Rewind on Resume
A dynamic backward offset applied automatically upon resuming playback. The offset duration scales based on the elapsed pause duration (e.g., 0s for short pauses, up to 30s for multi-hour/overnight pauses).

### Motion-Assisted Timer Reset
An energy-efficient accelerometer monitoring mode activated exclusively during the final warning window of a `SmartSleepTimer`. Physical movement above a user-configured threshold automatically resets the countdown.

### Jump Stack (`JumpHistory`)
A database-persisted stack of manual seek operations per `Audiobook`, storing timestamp snapshots before position mutations to allow reliable single-tap position recovery across app restarts.

---

## Library & Folder Organization

### Root Library Folder
A user-configured directory path registered in the application for scanning audiobooks. Multiple root folders can exist, each associated with a content category (e.g., Audiobooks, Podcasts).

### Cover Art Resolution Strategy
The resolution pipeline for book cover artwork:
1. Local `cover.jpg` / `cover.png` in book directory.
2. Embedded ID3 / MP4 metadata cover art.
3. Fallback online search query (only triggered with explicit user consent per book).
4. Generic placeholder fallback.

### Voice/Text Bookmark
A custom user marker bound to an exact timestamp, containing optional inline text notes or short voice recordings.

---

## Integrations & System Interfaces

### Car Mode
A specialized touch UI layout optimized for driving, featuring oversized touch targets, high-contrast typography, and swipe-gesture controls to minimize distraction.

### Media Controls Notification Integration
Enhanced system background media controls offering custom rewind/fast-forward actions, sleep-timer extension shortcuts, and bookmark creation directly from the lockscreen/notification shade.

### Voice Clarity Equalizer
A 5-band graphic equalizer profile with built-in voice frequency boost and volume gain controls tailored for spoken-word audio.

### Local Library Backup
A standalone JSON/ZIP archive exporter and importer for local playback history, position timestamps, and bookmarks, allowing complete manual or scheduled local restoration.

---

## Formats, Chaptering & eBook Sync

### Multi-File Virtual Audiobook
An `Audiobook` representation created from a directory containing multiple physical audio files (e.g., separate MP3 files per chapter), stitched together sequentially as a single continuous playback session.

### Embedded & Virtual Chapters
Chapter definitions extracted from container metadata (M4B/MP4 TOC) or created virtually by the user/system to demarcate logical sections within single-file or multi-file audiobooks.

### eBook-Assisted Silence Detection
An advanced chapter detection feature combining audio silence scanning with eBook text alignment (EPUB, PDF, LIT). The first few phrases following a detected audio silence are transcribed or matched against the eBook structure to confirm exact chapter boundaries and titles.

### Short Rewind Thresholds
- Pause < 5 min $\rightarrow$ 2s rewind (2,000 ms)
- Pause 5–15 min $\rightarrow$ 5s rewind (5,000 ms)
- Pause 15–60 min $\rightarrow$ 10s rewind (10,000 ms)
- Pause 1–8 hours $\rightarrow$ 20s rewind (20,000 ms)
- Pause > 8 hours $\rightarrow$ 30s rewind (30,000 ms)
