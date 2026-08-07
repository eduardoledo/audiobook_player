import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/audiobook.dart';
import '../models/detected_marker.dart';
import '../models/structure_detection_models.dart';
import 'chapter_structure_detector.dart';
import 'structure_detection_notifications.dart';
import 'whisper_model_manager.dart';

/// Long-lived structure detection job with pause/resume and partial markers.
class StructureDetectionJob extends ChangeNotifier {
  final WhisperModelManager modelManager;
  final StructureDetectionNotifications notifications;

  StructureDetectionJob({
    required this.modelManager,
    StructureDetectionNotifications? notifications,
  }) : notifications = notifications ?? StructureDetectionNotifications();

  StructureDetectionJobStatus status = StructureDetectionJobStatus.idle;
  Audiobook? book;
  String language = 'es';
  StructureDetectionProgress? progress;
  List<DetectedMarker> partialMarkers = const [];
  StructureDetectionCheckpoint? checkpoint;
  DateTime? startedAt;
  Object? error;
  bool panelOpen = false;

  ChapterStructureDetector? _detector;
  StreamSubscription<StructureDetectionEvent>? _subscription;
  bool _runningLoop = false;

  bool get isActive =>
      status == StructureDetectionJobStatus.running ||
      status == StructureDetectionJobStatus.paused;

  bool get hasJob => status != StructureDetectionJobStatus.idle;

  Future<void> start(
    Audiobook audiobook, {
    required String language,
  }) async {
    if (isActive && book?.path == audiobook.path) {
      return;
    }
    if (isActive) {
      await cancel(reset: true);
    }

    book = audiobook;
    this.language = language;
    status = StructureDetectionJobStatus.running;
    progress = null;
    partialMarkers = const [];
    checkpoint = null;
    error = null;
    startedAt = DateTime.now();
    panelOpen = true;
    notifyListeners();

    _detector?.dispose();
    _detector = ChapterStructureDetector(modelManager: modelManager);
    await _listen(
      _detector!.detectEvents(audiobook, language: language),
    );
  }

  Future<void> _listen(Stream<StructureDetectionEvent> stream) async {
    await _subscription?.cancel();
    _runningLoop = true;
    _subscription = stream.listen(
      (event) {
        progress = event.progress;
        partialMarkers = event.markers;
        if (event.checkpoint != null) {
          checkpoint = event.checkpoint;
        }
        if (event.done) {
          status = StructureDetectionJobStatus.completed;
        } else if (_detector?.isPaused == true) {
          status = StructureDetectionJobStatus.paused;
        } else {
          status = StructureDetectionJobStatus.running;
        }
        notifyListeners();
        unawaited(notifications.update(this));
      },
      onError: (Object e, StackTrace st) {
        _runningLoop = false;
        if (e.toString().contains('cancelled')) {
          if (status == StructureDetectionJobStatus.paused) {
            notifyListeners();
            unawaited(notifications.update(this));
            return;
          }
          _resetIdle();
          unawaited(notifications.cancel());
          return;
        }
        error = e;
        status = StructureDetectionJobStatus.error;
        notifyListeners();
        unawaited(notifications.update(this));
      },
      onDone: () {
        _runningLoop = false;
        if (status == StructureDetectionJobStatus.running) {
          // Stream ended without done flag — treat as completed if we have progress
          if (progress?.progress == 1.0) {
            status = StructureDetectionJobStatus.completed;
          }
        }
        notifyListeners();
        unawaited(notifications.update(this));
      },
      cancelOnError: false,
    );
  }

  /// Resume from last checkpoint after pause (or after applying partial).
  Future<void> resume() async {
    if (status == StructureDetectionJobStatus.paused &&
        _detector != null &&
        _runningLoop) {
      _detector!.resume();
      status = StructureDetectionJobStatus.running;
      notifyListeners();
      unawaited(notifications.update(this));
      return;
    }

    // Stream ended while paused (e.g. silence cancel tore down) — restart from cp
    final b = book;
    final cp = checkpoint;
    if (b == null) return;

    status = StructureDetectionJobStatus.running;
    error = null;
    notifyListeners();

    _detector?.dispose();
    _detector = ChapterStructureDetector(modelManager: modelManager);
    await _listen(
      _detector!.detectEvents(
        b,
        resumeFrom: cp,
        language: cp?.language ?? language,
      ),
    );
    unawaited(notifications.update(this));
  }

  void pause() {
    if (!isActive) return;
    _detector?.pause();
    status = StructureDetectionJobStatus.paused;
    if (progress != null) {
      progress = progress!.copyWith(
        status: 'Pausado',
        detail:
            'Detección en pausa. Podés aplicar resultados parciales o reanudar.',
        paused: true,
      );
    }
    notifyListeners();
    unawaited(notifications.update(this));
  }

  Future<void> cancel({bool reset = true}) async {
    _detector?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _runningLoop = false;
    _detector?.dispose();
    _detector = null;
    await notifications.cancel();
    if (reset) {
      _resetIdle();
    }
  }

  void minimize() {
    panelOpen = false;
    notifyListeners();
    unawaited(notifications.update(this));
  }

  void openPanel() {
    panelOpen = true;
    notifyListeners();
  }

  /// Clear completed/error job after user finishes review.
  void clear() {
    _detector?.dispose();
    _detector = null;
    _resetIdle();
    unawaited(notifications.cancel());
  }

  void _resetIdle() {
    status = StructureDetectionJobStatus.idle;
    book = null;
    language = 'es';
    progress = null;
    partialMarkers = const [];
    checkpoint = null;
    startedAt = null;
    error = null;
    panelOpen = false;
    notifyListeners();
  }

  /// Convert current partial markers using a short-lived detector.
  Future<List<Chapter>> markersToChapters(List<DetectedMarker> markers) async {
    final b = book;
    if (b == null) return const [];
    final converter = ChapterStructureDetector(modelManager: modelManager);
    try {
      return await converter.markersToChapters(b, markers);
    } finally {
      converter.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(cancel(reset: true));
    super.dispose();
  }
}
