import 'dart:convert';

/// Data structure representing serialized library progress and settings for export/import.
class LibraryBackupData {
  final int version;
  final DateTime exportedAt;
  final Map<String, dynamic> playbackStates;
  final List<dynamic> bookmarks;

  const LibraryBackupData({
    required this.version,
    required this.exportedAt,
    required this.playbackStates,
    required this.bookmarks,
  });

  String toJson() {
    return jsonEncode({
      'version': version,
      'exported_at': exportedAt.toIso8601String(),
      'playback_states': playbackStates,
      'bookmarks': bookmarks,
    });
  }

  factory LibraryBackupData.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return LibraryBackupData(
      version: map['version'] as int? ?? 1,
      exportedAt: DateTime.parse(map['exported_at'] as String),
      playbackStates: map['playback_states'] as Map<String, dynamic>? ?? {},
      bookmarks: map['bookmarks'] as List<dynamic>? ?? [],
    );
  }
}
