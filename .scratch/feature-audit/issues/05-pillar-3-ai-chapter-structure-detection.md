# 05 - Pillar 3: AI Chapter & Structure Detection Pipeline

Status: resolved
Type: task

## Goal
Audit on-device Whisper Sherpa ONNX transcription, FFmpeg candidate silence finder, keyword matcher, and structure review UI.

## Acceptance Criteria
- [x] Verified `WhisperAsrWorker` protocol commands (`init`, `transcribe`, `isOk`).
- [x] Fixed isolate lifecycle leak in `WhisperAsrWorker`: `_mainPort` is now recreatable across repeated sessions, preventing crash upon re-analyzing audiobooks.
- [x] Verified `KeywordChapterMatcher` chapter gap detection, bilingual token priority (prólogo/epílogo vs. capítulo), and contiguous chapter generation across 16 unit tests.
- [x] Verified silence candidate finder thresholds and bounds checking.

## Comments
Pillar 3 AI chapter detection pipeline audited, hardened, and verified with all tests passing.
