import 'dart:async';
import '../../../../models/audiobook.dart';
import '../../../../models/bookmark.dart';
import '../../../../services/audio_player_service.dart';
import '../../../../services/library_storage.dart';
import '../../domain/repositories/player_repository.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final AudioPlayerService _playerService;
  final LibraryStorage _storage;

  PlayerRepositoryImpl({
    required AudioPlayerService playerService,
    required LibraryStorage storage,
  })  : _playerService = playerService,
        _storage = storage;

  @override
  Stream<Duration> get positionStream => _playerService.positionStream;

  @override
  Stream<bool> get playingStream =>
      _playerService.playerStateStream.map((s) => s.playing);

  @override
  Stream<Duration?> get durationStream => _playerService.durationStream;

  @override
  Stream<Duration?> get sleepTimerStream {
    return Stream<Duration?>.multi((controller) {
      void listener() {
        if (!controller.isClosed) {
          controller.add(_playerService.sleepTimeRemaining.value);
        }
      }

      _playerService.sleepTimeRemaining.addListener(listener);
      controller.onCancel = () {
        _playerService.sleepTimeRemaining.removeListener(listener);
      };
    });
  }

  @override
  Audiobook? get currentAudiobook => _playerService.currentAudiobook;

  @override
  Duration get currentPosition => _playerService.position;

  @override
  double get currentSpeed => _playerService.speed;

  @override
  bool get isPlaying => _playerService.playing;

  @override
  Future<void> setAudiobook(
    Audiobook audiobook, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool rewindForResume = false,
  }) {
    return _playerService.setAudiobook(
      audiobook,
      chapterIndex: chapterIndex,
      position: position,
      rewindForResume: rewindForResume,
    );
  }

  @override
  Future<void> play() => _playerService.play();

  @override
  Future<void> pause() => _playerService.pause();

  @override
  Future<void> stop() => _playerService.stop();

  @override
  Future<void> seek(Duration position) => _playerService.seekToPosition(position);

  @override
  Future<void> setSpeed(double speed) => _playerService.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _playerService.player.setVolume(volume);

  @override
  Future<void> setSleepTimer(Duration duration) async {
    _playerService.setSleepTimer(duration);
  }

  @override
  Future<void> cancelSleepTimer() async {
    _playerService.cancelSleepTimer();
  }

  @override
  Future<List<Bookmark>> getBookmarks(String bookPath) {
    return _storage.getBookmarks(bookPath);
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) {
    return _storage.addBookmark(bookmark);
  }

  @override
  Future<void> removeBookmark(int bookmarkId) {
    return _storage.removeBookmark(bookmarkId);
  }
}
