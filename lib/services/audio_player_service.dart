import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../models/audiobook.dart';
import '../models/audio_eq_profile.dart';
import '../service_locator.dart';
import 'library_storage.dart';

/// Manages audio playback for audiobooks globally.
class AudioPlayerService {
  late final AudioPlayer _player;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  Audiobook? currentAudiobook;
  Timer? _progressTimer;

  bool _wasInterrupted = false;

  AudioPlayerService() {
    _initPlayer();
    // Automatically save progress every 5 seconds while playing
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _initAudioSession();
  }

  void _initPlayer() {
    if (Platform.isAndroid) {
      try {
        _equalizer = AndroidEqualizer();
        _loudnessEnhancer = AndroidLoudnessEnhancer();
        _player = AudioPlayer(
          audioPipeline: AudioPipeline(
            androidAudioEffects: [_equalizer!, _loudnessEnhancer!],
          ),
        );
        return;
      } catch (_) {}
    }
    _equalizer = null;
    _loudnessEnhancer = null;
    _player = AudioPlayer();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
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
              // Rewind by 0.5 seconds before resuming
              final pos = _player.position;
              final rewindPos = pos - const Duration(milliseconds: 500);
              _player.seek(rewindPos >= Duration.zero ? rewindPos : Duration.zero);
              _player.play();
            }
            break;
        }
      }
    });
  }

  void _saveProgress() {
    if (currentAudiobook != null && _player.playing) {
      final chapterIndex = _player.currentIndex ?? 0;
      final positionMs = _player.position.inMilliseconds;
      getIt<LibraryStorage>().savePlaybackProgress(currentAudiobook!.path, chapterIndex, positionMs);
    }
  }

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  Future<void> setAudiobook(Audiobook audiobook, {int chapterIndex = 0, Duration position = Duration.zero}) async {
    currentAudiobook = audiobook;
    getIt<LibraryStorage>().saveLastPlayedBook(audiobook.path);
    
    // Asynchronously load and apply settings
    _loadAndApplyAudioSettings(audiobook.path);

    final displayTitle = (audiobook.series != null && audiobook.series!.isNotEmpty)
        ? '${audiobook.series} - ${audiobook.title}'
        : audiobook.title;

    final playlist = audiobook.files.asMap().entries.map((entry) {
      final index = entry.key;
      final path = entry.value;
      final title = index < audiobook.chapters.length ? audiobook.chapters[index].title : 'Chapter ${index + 1}';
      
      return AudioSource.uri(
        Uri.file(path),
        tag: MediaItem(
          id: '${audiobook.path}_$index',
          album: title,
          title: displayTitle,
          artist: audiobook.author,
        ),
      );
    }).toList();
    await _player.setAudioSources(playlist, initialIndex: chapterIndex, initialPosition: position);
  }

  Future<void> _loadAndApplyAudioSettings(String bookPath) async {
    try {
      final settings = await getIt<LibraryStorage>().getBookAudioSettings(bookPath);
      if (settings != null) {
        final eqPresetName = settings['eq_preset'] as String?;
        final loudnessEnabled = (settings['loudness_enabled'] as int?) == 1;
        final loudnessGain = (settings['loudness_gain'] as num?)?.toDouble() ?? 3.0;

        if (eqPresetName != null) {
          final preset = AudioEqPreset.presets.firstWhere(
            (p) => p.name == eqPresetName,
            orElse: () => AudioEqPreset.presets[0],
          );
          await applyEqPreset(preset);
        }

        if (_loudnessEnhancer != null) {
          await setLoudnessEnhancerGain(loudnessEnabled ? loudnessGain : 0.0);
        }
      } else {
        await applyEqPreset(AudioEqPreset.presets[0]);
        if (_loudnessEnhancer != null) {
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
    await getIt<LibraryStorage>().saveBookAudioSettings(
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
      await _player.seek(Duration.zero, index: chapterIndex);
    }
  }

  Future<void> seekToPosition(Duration position) async {
    await _player.seek(position);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  int? getCurrentChapterIndex(Audiobook audiobook) {
    return _player.currentIndex;
  }

  AndroidEqualizer? get equalizer => _equalizer;

  Future<void> applyEqPreset(AudioEqPreset preset) async {
    final eq = _equalizer;
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
    final eq = _equalizer;
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

  AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;

  Future<void> setLoudnessEnhancerGain(double db) async {
    final enhancer = _loudnessEnhancer;
    if (enhancer == null) return;
    try {
      final mB = (db * 100.0);
      await enhancer.setTargetGain(mB);
    } catch (_) {}
  }

  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _player.dispose();
  }
}
