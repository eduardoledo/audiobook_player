# 07: Voice Clarity Equalizer & Local JSON/ZIP Backup

**What to build:**
A 5-band graphic equalizer profile with speech clarity boost stored per book, alongside local JSON/ZIP export and import tools for database progress, position history, and bookmarks.

**Blocked by:** 01-per-book-state-and-short-rewind

**Status:** ready-for-agent

- [ ] 5-band equalizer control interface with "Voice Clarity" frequency preset
- [ ] Equalizer parameters saved and restored per `Audiobook`
- [ ] Export library progress, position snapshots, and bookmarks to a local JSON/ZIP archive
- [ ] Import archive to restore full listening state across device reinstalls
- [ ] Unit tests for backup serialization and deserialization accuracy
