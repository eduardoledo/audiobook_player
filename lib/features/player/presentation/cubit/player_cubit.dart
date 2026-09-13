import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/audiobook.dart';
import '../../../../models/bookmark.dart';
import '../../domain/repositories/player_repository.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerState> {
  final PlayerRepository _playerRepository;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration?>? _sleepTimerSubscription;

  PlayerCubit({
    required PlayerRepository playerRepository,
  })  : _playerRepository = playerRepository,
        super(const PlayerState()) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _positionSubscription = _playerRepository.positionStream.listen((pos) {
      emit(state.copyWith(position: pos));
    });

    _playingSubscription = _playerRepository.playingStream.listen((playing) {
      emit(state.copyWith(isPlaying: playing));
    });

    _durationSubscription = _playerRepository.durationStream.listen((dur) {
      if (dur != null) {
        emit(state.copyWith(duration: dur));
      }
    });

    _sleepTimerSubscription = _playerRepository.sleepTimerStream.listen((remaining) {
      emit(state.copyWith(
        sleepTimerRemaining: remaining,
        clearSleepTimer: remaining == null,
      ));
    });
  }

  Future<void> initAudiobook(Audiobook audiobook) async {
    emit(state.copyWith(
      audiobook: audiobook,
      speed: _playerRepository.currentSpeed,
      isPlaying: _playerRepository.isPlaying,
    ));
    await loadBookmarks();
  }

  Future<void> playAudiobook(
    Audiobook audiobook, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool rewindForResume = false,
  }) async {
    emit(state.copyWith(audiobook: audiobook, currentChapterIndex: chapterIndex));
    await _playerRepository.setAudiobook(
      audiobook,
      chapterIndex: chapterIndex,
      position: position,
      rewindForResume: rewindForResume,
    );
    await loadBookmarks();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _playerRepository.pause();
    } else {
      await _playerRepository.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _playerRepository.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _playerRepository.setSpeed(speed);
    emit(state.copyWith(speed: speed));
  }

  Future<void> setSleepTimer(Duration duration) async {
    await _playerRepository.setSleepTimer(duration);
  }

  Future<void> cancelSleepTimer() async {
    await _playerRepository.cancelSleepTimer();
    emit(state.copyWith(clearSleepTimer: true));
  }

  Future<void> loadBookmarks() async {
    final book = state.audiobook;
    if (book == null) return;
    final bookmarks = await _playerRepository.getBookmarks(book.path);
    emit(state.copyWith(bookmarks: bookmarks));
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    await _playerRepository.addBookmark(bookmark);
    await loadBookmarks();
  }

  Future<void> removeBookmark(int bookmarkId) async {
    await _playerRepository.removeBookmark(bookmarkId);
    await loadBookmarks();
  }

  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _sleepTimerSubscription?.cancel();
    return super.close();
  }
}
