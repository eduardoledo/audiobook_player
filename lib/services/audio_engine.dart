import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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

/// Production [AudioEngine] backed by `just_audio` and `audio_session`.
class JustAudioEngine extends AudioEngine {
  late final AudioPlayer _player;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  final StreamController<AudioInterruptionEvent> _interruptionController =
      StreamController<AudioInterruptionEvent>.broadcast();
  StreamSubscription<AudioInterruptionEvent>? _sessionSubscription;

  JustAudioEngine() {
    if (Platform.isAndroid) {
      try {
        _equalizer = AndroidEqualizer();
        _loudnessEnhancer = AndroidLoudnessEnhancer();
        _player = AudioPlayer(
          audioPipeline: AudioPipeline(
            androidAudioEffects: [_equalizer!, _loudnessEnhancer!],
          ),
        );
      } catch (_) {
        _equalizer = null;
        _loudnessEnhancer = null;
        _player = AudioPlayer();
      }
    } else {
      _equalizer = null;
      _loudnessEnhancer = null;
      _player = AudioPlayer();
    }
    unawaited(_initAudioSession());
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _sessionSubscription = session.interruptionEventStream.listen((event) {
      if (!_interruptionController.isClosed) {
        _interruptionController.add(event);
      }
    });
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<double> get speedStream => _player.speedStream;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _interruptionController.stream;

  @override
  bool get playing => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  PlayerState get playerState => _player.playerState;

  @override
  double get speed => _player.speed;

  @override
  double get volume => _player.volume;

  @override
  AndroidEqualizer? get equalizer => _equalizer;

  @override
  AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;

  @override
  Future<void> setPlaylist(
    List<AudioTrackItem> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    final playlist = tracks
        .map(
          (t) => AudioSource.uri(
            Uri.file(t.filePath),
            tag: MediaItem(
              id: t.id,
              album: t.album,
              title: t.title,
              artist: t.artist,
            ),
          ),
        )
        .toList();

    await _player.setAudioSources(
      playlist,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> seek(Duration position, {int? index}) {
    return _player.seek(position, index: index);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _sessionSubscription?.cancel();
    await _interruptionController.close();
    await _player.dispose();
  }
}

