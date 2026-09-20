# Issue 03: Embedded Remote Web SPA Assets & Player/Library UI

## Status

- [ ] Spec: [.scratch/embedded-web-server/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/embedded-web-server/spec.md)

## Goal

Build a modern HTML5/CSS/JS Web SPA embedded in Flutter assets that provides real-time player remote control, category library browser, and drag-and-drop file uploader.

## Tasks

- [ ] Create `assets/web_remote/` SPA with responsive layout, player controller bar, and dark theme.
- [ ] Connect Web SPA WebSocket to `/ws/playback` for real-time play/pause, seek, chapter, and progress updates.
- [ ] Build Nested Set category library tree view rendering audiobooks and eBooks.
- [ ] Implement drag-and-drop file upload zone sending files to `/api/upload`.
- [ ] Configure Flutter asset bundle and `shelf_static` asset handler to serve the Web SPA.
