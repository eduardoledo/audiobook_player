import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';

import '../models/audiobook.dart';
import '../service_locator.dart';
import 'library_storage.dart';

/// Manages audio playback for audiobooks globally.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  Audiobook? currentAudiobook;
  Timer? _progressTimer;

  bool _wasInterrupted = false;

  AudioPlayerService() {
    // Automatically save progress every 5 seconds while playing
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _initAudioSession();
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
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: audiobook.files.asMap().entries.map((entry) {
        final index = entry.key;
        final path = entry.value;
        final title = index < audiobook.chapters.length ? audiobook.chapters[index].title : 'Chapter ${index + 1}';
        
        return AudioSource.uri(
          Uri.file(path),
          tag: MediaItem(
            id: '${audiobook.path}_$index',
            album: audiobook.title,
            title: title,
            artist: audiobook.author,
          ),
        );
      }).toList(),
    );
    await _player.setAudioSource(playlist, initialIndex: chapterIndex, initialPosition: position);
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

  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _player.dispose();
  }
}
