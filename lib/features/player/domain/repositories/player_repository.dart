import 'dart:async';
import '../../../../models/audiobook.dart';
import '../../../../models/bookmark.dart';

abstract class PlayerRepository {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<Duration?> get durationStream;
  Stream<Duration?> get sleepTimerStream;

  Audiobook? get currentAudiobook;
  Duration get currentPosition;
  double get currentSpeed;
  bool get isPlaying;

  Future<void> setAudiobook(
    Audiobook audiobook, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool rewindForResume = false,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setSleepTimer(Duration duration);
  Future<void> cancelSleepTimer();

  Future<List<Bookmark>> getBookmarks(String bookPath);
  Future<void> addBookmark(Bookmark bookmark);
  Future<void> removeBookmark(int bookmarkId);
}
