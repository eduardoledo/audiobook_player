# Feature Audit & Comprehensive Improvements Spec

## Overview
Comprehensive vertical verification and quality-of-life improvements across all 4 core pillars of the Audiobook Player app. Work is executed subsystem by subsystem with unit testing, bug hardening, UI de-bloating, and formal localization (`en` and `es`).

## Architecture & Subsystems
- **Pillar 1: Core Audio Playback & Player UX**: Playback reliability, audio session interrupts, resume rewind, bookmarks, sleep timer, EQ sheet.
- **Pillar 2: Library Scanner & Hierarchical Structure**: Directory scanner, path pattern rules (`Author / Universe / Saga / Era / Book`), series sorting, metadata persistence, and `HomeScreen` modularization.
- **Pillar 3: AI Chapter & Structure Detection**: On-device Whisper Sherpa ONNX, FFmpeg silence candidate finder, keyword matcher, and review UI.
- **Pillar 4: E-Reader & Cloud Sync**: EPUB reader, PDF viewer, Google Drive authentication and syncing.

## Execution Plan
1. **Foundation**: Configure standard Flutter localization infrastructure (`l10n.yaml`, ARB files for `en` and `es`).
2. **Pillar 2 (Library Scanner & Hierarchy)**:
   - Audit `AudiobookScanner` and `PathPatternRule` against edge cases.
   - De-bloat `HomeScreen` (1,921 lines) into modular widgets.
   - Add library search and sorting QoL controls.
   - Migrate hardcoded strings to localization keys.
3. **Pillar 1 (Core Audio Playback Engine)**:
   - Verify audio focus/interrupt handling and resume seek.
   - Add sleep timer and playback controls QoL.
   - Localize `PlayerScreen`.
4. **Pillar 3 (AI Chapter & Structure Detection)**:
   - Verify isolate lifecycle, memory consumption, and error handling.
   - Localize structure detection dialogs and review screen.
5. **Pillar 4 (E-Reader & Cloud Sync)**:
   - Verify EPUB/PDF reading progress and Google Drive sync robustness.
