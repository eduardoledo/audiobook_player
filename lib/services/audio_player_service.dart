import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audiobook.dart';
import '../models/audio_eq_profile.dart';
import '../service_locator.dart';
import 'audio_engine.dart';
import 'audiobook_scanner.dart';
import 'library_storage.dart';

/// Manages audio playback for audiobooks globally.
class AudioPlayerService {
  final AudioEngine _engine;
  final LibraryStorage? _storageOverride;
  final Future<Duration?> Function(String filePath) fileDurationProbe;
  Audiobook? currentAudiobook;
  Timer? _progressTimer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  bool _wasInterrupted = false;

  AudioPlayerService({
    AudioEngine? engine,
    LibraryStorage? storage,
    Future<Duration?> Function(String filePath)? fileDurationProbe,
    bool enablePeriodicSave = true,
  })  : _engine = engine ?? JustAudioEngine(),
        _storageOverride = storage,
        fileDurationProbe = fileDurationProbe ?? _defaultFileDurationProbe {
    _initListeners();
    if (enablePeriodicSave) {
      // Guarda el progreso cada minuto de forma segura
      _progressTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_saveProgress()),
      );
    }
  }

  static Future<Duration?> _defaultFileDurationProbe(String filePath) async {
    final meta = await AudiobookScanner.getAudioMetadata(File(filePath));
    return meta?.duration;
  }

  LibraryStorage get _storage => _storageOverride ?? getIt<LibraryStorage>();

  void _initListeners() {
    // Guardar progreso al pausar
    _playerStateSub = _engine.playerStateStream.listen((state) {
      if (!state.playing) {
        unawaited(_saveProgress());
      }
    });

    // Guardar progreso al cambiar de capítulo y verificar temporizador
    _currentIndexSub = _engine.currentIndexStream.listen((index) {
      if (index != null) {
        unawaited(_saveProgress());
        if (_sleepAtChapterEnd) {
          cancelSleepTimer();
          unawaited(pause());
        }
      }
    });

    _interruptionSub = _engine.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_engine.playing) {
              _wasInterrupted = true;
            }
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_wasInterrupted) {
              _wasInterrupted = false;
              unawaited(play());
            }
            break;
        }
      }
    });
  }

  bool _isSavingProgress = false;
  bool _suppressProgressSave = false;

  /// When true, the next [play] from a paused position rewinds by [resumeRewind].
  /// Cleared after a resume seek in [setAudiobook] so open+play does not double-rewind.
  bool _rewindOnNextPlay = true;

  Future<void> _saveProgress() async {
    if (currentAudiobook == null) return;
    if (_isSavingProgress || _suppressProgressSave) return;

    try {
      _isSavingProgress = true;
      final chapterIndex = _engine.currentIndex ?? 0;
      final positionMs = _engine.position.inMilliseconds;
      await _storage.savePlaybackProgress(
        currentAudiobook!.path,
        chapterIndex,
        positionMs,
      );
    } catch (e) {
      debugPrint('Error saving progress: $e');
    } finally {
      _isSavingProgress = false;
    }
  }

  /// How far to rewind when resuming from a saved or paused position.
  static const Duration resumeRewind = Duration(seconds: 1);

  /// Returns [saved] minus [resumeRewind], floored at zero.
  static Duration positionForResume(Duration saved) {
    if (saved <= resumeRewind) return Duration.zero;
    return saved - resumeRewind;
  }

  Stream<Duration> get positionStream => _engine.positionStream;
  Stream<Duration?> get durationStream => _engine.durationStream;
  Stream<PlayerState> get playerStateStream => _engine.playerStateStream;
  Stream<int?> get currentIndexStream => _engine.currentIndexStream;

  bool get playing => _engine.playing;

  Duration get position => _engine.position;
  Duration? get duration => _engine.duration;
  PlayerState get playerState => _engine.playerState;

  Future<void> setAudiobook(
    Audiobook audiobook, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool rewindForResume = false,
  }) async {
    currentAudiobook = audiobook;
    unawaited(_storage.saveLastPlayedBook(audiobook.path));

    // Asynchronously load and apply settings
    unawaited(_loadAndApplyAudioSettings(audiobook.path));

    final displayTitle =
        (audiobook.series != null && audiobook.series!.isNotEmpty)
            ? '${audiobook.series} - ${audiobook.title}'
            : audiobook.title;

    final tracks = audiobook.files.asMap().entries.map((entry) {
      final index = entry.key;
      final path = entry.value;
      final title = index < audiobook.chapters.length
          ? audiobook.chapters[index].title
          : 'Chapter ${index + 1}';

      return AudioTrackItem(
        id: '${audiobook.path}_$index',
        filePath: path,
        album: title,
        title: displayTitle,
        artist: audiobook.author,
      );
    }).toList();

    final startPosition =
        rewindForResume ? positionForResume(position) : position;

    // Already applied resume rewind on load; avoid a second rewind on first play.
    _rewindOnNextPlay = !rewindForResume;

    // Avoid persisting the rewound position as progress before the user plays.
    _suppressProgressSave = true;
    try {
      await _engine.setPlaylist(
        tracks,
        initialIndex: chapterIndex,
        initialPosition: startPosition,
      );
      // Some backends ignore initialPosition; seek explicitly after load.
      if (startPosition > Duration.zero) {
        await _engine.seek(startPosition, index: chapterIndex);
      }
    } finally {
      _suppressProgressSave = false;
    }
  }

  Future<void> _loadAndApplyAudioSettings(String bookPath) async {
    try {
      final settings = await _storage.getBookAudioSettings(bookPath);
      if (settings != null) {
        final eqPresetName = settings['eq_preset'] as String?;
        final loudnessEnabled = (settings['loudness_enabled'] as int?) == 1;
        final loudnessGain =
            (settings['loudness_gain'] as num?)?.toDouble() ?? 3.0;

        if (eqPresetName != null) {
          final preset = AudioEqPreset.presets.firstWhere(
            (p) => p.name == eqPresetName,
            orElse: () => AudioEqPreset.presets[0],
          );
          await applyEqPreset(preset);
        }

        if (loudnessEnhancer != null) {
          await setLoudnessEnhancerGain(loudnessEnabled ? loudnessGain : 0.0);
        }
      } else {
        await applyEqPreset(AudioEqPreset.presets[0]);
        if (loudnessEnhancer != null) {
          await setLoudnessEnhancerGain(0.0);
        }
      }
    } catch (_) {}
  }

  Future<void> saveCurrentAudioSettings({
    required String eqPreset,
    required bool loudnessEnabled,
    required double loudnessGain,
    required bool skipSilences,
    required bool pitchStabilized,
  }) async {
    final book = currentAudiobook;
    if (book == null) return;
    await _storage.saveBookAudioSettings(
      bookPath: book.path,
      eqPreset: eqPreset,
      loudnessEnabled: loudnessEnabled,
      loudnessGain: loudnessGain,
      skipSilences: skipSilences,
      pitchStabilized: pitchStabilized,
    );
  }

  Future<void> seekToChapter(Audiobook audiobook, int chapterIndex) async {
    if (chapterIndex >= 0 && chapterIndex < audiobook.chapters.length) {
      if (audiobook.files.length <= 1) {
        final startMs = (audiobook.chapters[chapterIndex].start * 1000).round();
        await _engine.seek(Duration(milliseconds: startMs), index: 0);
      } else {
        await _engine.seek(Duration.zero, index: chapterIndex);
      }
    }
  }

  Future<void> seekToPosition(Duration position) async {
    await _engine.seek(position);
  }

  Future<void> seekToBookPosition(
    Audiobook audiobook,
    Duration globalPosition,
  ) async {
    final targetGlobalMs =
        globalPosition.inMilliseconds < 0 ? 0 : globalPosition.inMilliseconds;
    _rewindOnNextPlay = false;

    if (audiobook.files.length <= 1) {
      final totalMs = (audiobook.chapters.fold<double>(
                0.0,
                (sum, c) => sum + c.duration,
              ) *
              1000)
          .round();
      final clampedMs =
          totalMs > 0 ? targetGlobalMs.clamp(0, totalMs) : targetGlobalMs;
      await _engine.seek(Duration(milliseconds: clampedMs), index: 0);
      return;
    }

    var remainingMs = targetGlobalMs;
    for (var i = 0; i < audiobook.files.length; i++) {
      final fileDurMs = i < audiobook.chapters.length
          ? (audiobook.chapters[i].duration * 1000).round()
          : 0;
      if ((fileDurMs > 0 && remainingMs < fileDurMs) ||
          i == audiobook.files.length - 1) {
        final localMs = fileDurMs > 0
            ? remainingMs.clamp(0, fileDurMs)
            : (remainingMs < 0 ? 0 : remainingMs);
        await _engine.seek(Duration(milliseconds: localMs), index: i);
        return;
      }
      remainingMs -= fileDurMs;
    }
  }

  Future<void> play() async {
    if (!_engine.playing &&
        _engine.position > Duration.zero &&
        _rewindOnNextPlay) {
      _suppressProgressSave = true;
      try {
        await _engine.seek(positionForResume(_engine.position));
      } finally {
        _suppressProgressSave = false;
      }
    }
    // After this play, the next pause→play should rewind again.
    _rewindOnNextPlay = true;
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();
  Future<void> stop() => _engine.stop();

  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);
  Future<void> setVolume(double volume) => _engine.setVolume(volume);
  double get speed => _engine.speed;
  Stream<double> get speedStream => _engine.speedStream;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  final ValueNotifier<Duration?> sleepTimeRemaining = ValueNotifier(null);
  bool _sleepAtChapterEnd = false;

  bool get isSleepTimerActive => _sleepTimer != null || _sleepAtChapterEnd;
  bool get sleepAtChapterEnd => _sleepAtChapterEnd;

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerEndTime = DateTime.now().add(duration);
    sleepTimeRemaining.value = duration;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining =
          _sleepTimerEndTime?.difference(DateTime.now()) ?? Duration.zero;
      if (remaining <= Duration.zero) {
        cancelSleepTimer();
        await _fadeAndPause();
      } else {
        sleepTimeRemaining.value = remaining;
      }
    });
  }

  void setSleepAtChapterEnd() {
    cancelSleepTimer();
    _sleepAtChapterEnd = true;
    sleepTimeRemaining.value = null;
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _sleepAtChapterEnd = false;
    sleepTimeRemaining.value = null;
  }

  Future<void> _fadeAndPause() async {
    if (_engine.playing) {
      final currentVol = _engine.volume;
      for (int i = 10; i >= 0; i--) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _engine.setVolume(currentVol * (i / 10.0));
      }
      await pause();
      await _engine.setVolume(currentVol);
    }
  }

  int? getCurrentChapterIndex(Audiobook audiobook) {
    if (audiobook.files.length <= 1 && audiobook.chapters.isNotEmpty) {
      final chapter = resolveChapterForGlobalPosition(
        audiobook,
        _engine.position.inMilliseconds,
      );
      if (chapter == null) return 0;
      final idx = audiobook.chapters.indexOf(chapter);
      return idx >= 0 ? idx : 0;
    }
    return _engine.currentIndex;
  }

  int getGlobalPositionMs(
    Audiobook audiobook, {
    int? trackIndex,
    Duration? trackPosition,
  }) {
    final localPosMs = (trackPosition ?? _engine.position).inMilliseconds;
    if (audiobook.files.length <= 1) {
      return localPosMs;
    }
    final activeIndex = trackIndex ?? _engine.currentIndex ?? 0;
    var precedingMs = 0;
    for (var i = 0; i < activeIndex && i < audiobook.chapters.length; i++) {
      precedingMs += (audiobook.chapters[i].duration * 1000).round();
    }
    return precedingMs + localPosMs;
  }

  Chapter? resolveChapterForGlobalPosition(
    Audiobook audiobook,
    int globalPositionMs,
  ) {
    if (audiobook.chapters.isEmpty) return null;
    final globalSeconds = globalPositionMs / 1000.0;
    var cumulativeStart = 0.0;
    for (final chapter in audiobook.chapters) {
      final hasExplicitRange = chapter.end > chapter.start;
      final start = hasExplicitRange ? chapter.start : cumulativeStart;
      final end =
          hasExplicitRange ? chapter.end : cumulativeStart + chapter.duration;
      cumulativeStart = end;
      if (globalSeconds >= start && globalSeconds < end) {
        return chapter;
      }
    }
    if (globalSeconds < audiobook.chapters.first.start) {
      return audiobook.chapters.first;
    }
    return audiobook.chapters.last;
  }

  AndroidEqualizer? get equalizer => _engine.equalizer;

  Future<void> applyEqPreset(AudioEqPreset preset) async {
    final eq = equalizer;
    if (eq == null) return;
    try {
      final parameters = await eq.parameters;
      final bands = parameters.bands;
      for (int i = 0; i < bands.length; i++) {
        final band = bands[i];
        final freq = band.centerFrequency;

        // Map center frequency to our 5 abstract preset bands:
        // [Low (<150Hz), Mid-Low (150-500Hz), Mid (500-2000Hz), Mid-High (2000-8000Hz), High (>8000Hz)]
        double targetGain = 0.0;
        if (freq < 150) {
          targetGain = preset.gains[0];
        } else if (freq < 500) {
          targetGain = preset.gains[1];
        } else if (freq < 2000) {
          targetGain = preset.gains[2];
        } else if (freq < 8000) {
          targetGain = preset.gains[3];
        } else {
          targetGain = preset.gains[4];
        }

        final minGain = parameters.minDecibels;
        final maxGain = parameters.maxDecibels;
        final clampedGain = targetGain.clamp(minGain, maxGain);

        await band.setGain(clampedGain);
      }
    } catch (e) {
      debugPrint('Error applying EQ preset: $e');
    }
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    final eq = equalizer;
    if (eq == null) return;
    try {
      final parameters = await eq.parameters;
      if (bandIndex >= 0 && bandIndex < parameters.bands.length) {
        final minGain = parameters.minDecibels;
        final maxGain = parameters.maxDecibels;
        await parameters.bands[bandIndex].setGain(gain.clamp(minGain, maxGain));
      }
    } catch (_) {}
  }

  AndroidLoudnessEnhancer? get loudnessEnhancer => _engine.loudnessEnhancer;

  Future<void> setLoudnessEnhancerGain(double db) async {
    final enhancer = loudnessEnhancer;
    if (enhancer == null) return;
    try {
      final mB = (db * 100.0);
      await enhancer.setTargetGain(mB);
    } catch (_) {}
  }

  void dispose() {
    _progressTimer?.cancel();
    cancelSleepTimer();
    unawaited(_saveProgress());
    unawaited(_playerStateSub?.cancel());
    unawaited(_currentIndexSub?.cancel());
    unawaited(_interruptionSub?.cancel());
    unawaited(_engine.dispose());
  }
}
