/// Represents the isolated playback configuration and position for a specific audiobook.
class BookPlaybackState {
  final String bookPath;
  final int positionMs;
  final int chapterIndex;
  final double playbackSpeed;
  final double volumeGain;
  final DateTime? lastPlayedTimestamp;

  const BookPlaybackState({
    required this.bookPath,
    this.positionMs = 0,
    this.chapterIndex = 0,
    this.playbackSpeed = 1.0,
    this.volumeGain = 1.0,
    this.lastPlayedTimestamp,
  });

  BookPlaybackState copyWith({
    int? positionMs,
    int? chapterIndex,
    double? playbackSpeed,
    double? volumeGain,
    DateTime? lastPlayedTimestamp,
  }) {
    return BookPlaybackState(
      bookPath: bookPath,
      positionMs: positionMs ?? this.positionMs,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volumeGain: volumeGain ?? this.volumeGain,
      lastPlayedTimestamp: lastPlayedTimestamp ?? this.lastPlayedTimestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_path': bookPath,
      'position_ms': positionMs,
      'chapter_index': chapterIndex,
      'playback_speed': playbackSpeed,
      'volume_gain': volumeGain,
      'last_played_timestamp': lastPlayedTimestamp?.millisecondsSinceEpoch,
    };
  }

  factory BookPlaybackState.fromMap(Map<String, dynamic> map, String path) {
    return BookPlaybackState(
      bookPath: path,
      positionMs: map['position_ms'] as int? ?? 0,
      chapterIndex: map['chapter_index'] as int? ?? 0,
      playbackSpeed: (map['playback_speed'] as num?)?.toDouble() ?? 1.0,
      volumeGain: (map['volume_gain'] as num?)?.toDouble() ?? 1.0,
      lastPlayedTimestamp: map['last_played_timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_timestamp'] as int)
          : null,
    );
  }
}
