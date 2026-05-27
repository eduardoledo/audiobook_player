import 'package:just_audio/just_audio.dart';

import '../models/audiobook.dart';

/// Manages audio playback for audiobooks.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  Future<void> setAudiobook(Audiobook audiobook, {int chapterIndex = 0}) async {
    await _player.setFilePath(audiobook.fullPath);
    if (audiobook.chapters.isNotEmpty && chapterIndex < audiobook.chapters.length) {
      final chapter = audiobook.chapters[chapterIndex];
      await _player.seek(Duration(milliseconds: (chapter.start * 1000).round()));
    }
  }

  Future<void> seekToChapter(Audiobook audiobook, int chapterIndex) async {
    if (chapterIndex >= 0 && chapterIndex < audiobook.chapters.length) {
      final chapter = audiobook.chapters[chapterIndex];
      await _player.seek(Duration(milliseconds: (chapter.start * 1000).round()));
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
    final posSec = _player.position.inMilliseconds / 1000.0;
    for (var i = audiobook.chapters.length - 1; i >= 0; i--) {
      if (posSec >= audiobook.chapters[i].start) {
        return i;
      }
    }
    return 0;
  }

  void dispose() {
    _player.dispose();
  }
}
