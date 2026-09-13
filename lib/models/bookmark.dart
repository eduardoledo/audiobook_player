class Bookmark {
  final int? id;
  final String bookPath;
  final int positionMs;
  final String? label;
  final String? textNote;
  final String? audioNotePath;
  final DateTime? createdAt;

  const Bookmark({
    this.id,
    required this.bookPath,
    required this.positionMs,
    this.label,
    this.textNote,
    this.audioNotePath,
    this.createdAt,
  });

  String get positionFormatted {
    final d = Duration(milliseconds: positionMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_path': bookPath,
      'position_ms': positionMs,
      'label': label,
      'text_note': textNote,
      'audio_note_path': audioNotePath,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookPath: map['book_path'] as String? ?? '',
      positionMs: map['position_ms'] as int? ?? 0,
      label: map['label'] as String?,
      textNote: map['text_note'] as String?,
      audioNotePath: map['audio_note_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
    );
  }
}
