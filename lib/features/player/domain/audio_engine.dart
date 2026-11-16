import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Metadata and file location for a single playable audio track.
class AudioTrackItem {
  final String id;
  final String filePath;
  final String title;
  final String album;
  final String artist;

  const AudioTrackItem({
    required this.id,
    required this.filePath,
    required this.title,
    required this.album,
    required this.artist,
  });
}

/// Hardware/platform seam for low-level audio playback.
abstract class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlayerState> get playerStateStream;
  Stream<int?> get currentIndexStream;
  Stream<double> get speedStream;
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      const Stream<AudioInterruptionEvent>.empty();

  bool get playing;
  Duration get position;
  Duration? get duration;
  int? get currentIndex;
  PlayerState get playerState;
  double get speed;
  double get volume;

  AndroidEqualizer? get equalizer => null;
  AndroidLoudnessEnhancer? get loudnessEnhancer => null;

  Future<void> setPlaylist(
    List<AudioTrackItem> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  });

  Future<void> seek(Duration position, {int? index});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

