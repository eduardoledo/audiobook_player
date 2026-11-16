import 'dart:async';
import 'package:audiobook_player/features/player/domain/audio_engine.dart';
import 'package:just_audio/just_audio.dart';

class FakeAudioEngine extends AudioEngine {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  final Map<String, Duration> trackDurationsByPath;

  List<AudioTrackItem> loadedTracks = const [];
  int? _currentIndex;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  double _speed = 1.0;
  double _volume = 1.0;

  FakeAudioEngine({this.trackDurationsByPath = const {}});

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  bool get playing => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  int? get currentIndex => _currentIndex;

  @override
  PlayerState get playerState => PlayerState(_playing, _processingState);

  @override
  double get speed => _speed;

  @override
  double get volume => _volume;

  Duration? _durationForIndex(int? index) {
    if (index == null || index < 0 || index >= loadedTracks.length) {
      return null;
    }
    return trackDurationsByPath[loadedTracks[index].filePath];
  }

  @override
  Future<void> setPlaylist(
    List<AudioTrackItem> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    loadedTracks = List<AudioTrackItem>.unmodifiable(tracks);
    _currentIndex = tracks.isEmpty ? null : initialIndex;
    _position = initialPosition;
    _duration = _durationForIndex(_currentIndex);
    _processingState = ProcessingState.ready;

    _currentIndexController.add(_currentIndex);
    _durationController.add(_duration);
    _positionController.add(_position);
    _playerStateController.add(playerState);
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    if (index != null && index != _currentIndex) {
      _currentIndex = index;
      _duration = _durationForIndex(_currentIndex);
      _currentIndexController.add(_currentIndex);
      _durationController.add(_duration);
    }
    _position = position;
    _positionController.add(_position);
  }

  @override
  Future<void> play() async {
    _playing = true;
    _processingState = ProcessingState.ready;
    _playerStateController.add(playerState);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playerStateController.add(playerState);
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _processingState = ProcessingState.idle;
    _playerStateController.add(playerState);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    _speedController.add(_speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  void emitPosition(Duration position) {
    _position = position;
    _positionController.add(_position);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playerStateController.close();
    await _currentIndexController.close();
    await _speedController.close();
  }
}

