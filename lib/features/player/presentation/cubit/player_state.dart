import 'package:equatable/equatable.dart';
import '../../../../models/audiobook.dart';
import '../../../../models/bookmark.dart';

class PlayerState extends Equatable {
  final Audiobook? audiobook;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double speed;
  final int currentChapterIndex;
  final Duration? sleepTimerRemaining;
  final List<Bookmark> bookmarks;

  const PlayerState({
    this.audiobook,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.speed = 1.0,
    this.currentChapterIndex = 0,
    this.sleepTimerRemaining,
    this.bookmarks = const [],
  });

  PlayerState copyWith({
    Audiobook? audiobook,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    double? speed,
    int? currentChapterIndex,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
    List<Bookmark>? bookmarks,
  }) {
    return PlayerState(
      audiobook: audiobook ?? this.audiobook,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      sleepTimerRemaining:
          clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }

  @override
  List<Object?> get props => [
        audiobook,
        position,
        duration,
        isPlaying,
        speed,
        currentChapterIndex,
        sleepTimerRemaining,
        bookmarks,
      ];
}
