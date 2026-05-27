import 'package:path/path.dart' as p;

/// Represents an audiobook with metadata and chapters.
class Audiobook {
  // final String id;
  final String path;
  final String title;
  final String author;
  final String? album;
  final List<String> files;
  // final double duration;
  final String durationFormatted;
  final int totalChapters;
  final List<Chapter> chapters;

  const Audiobook({
    // required this.id,
    required this.path,
    required this.title,
    required this.author,
    this.album,
    required this.files,
    // required this.duration,
    required this.durationFormatted,
    required this.totalChapters,
    required this.chapters,
  });

  factory Audiobook.fromJson(Map<String, dynamic> json, String basePath) {
    final chaptersJson = json['chapters'] as List<dynamic>? ?? [];
    final chapters = chaptersJson
        .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
        .toList();

    final audio = json['audio'] as Map<String, dynamic>? ?? {};

    return Audiobook(
      // id: '${basePath}_${json['files'] ?? ''}',
      path: basePath,
      title: json['title'] as String? ?? 'Unknown',
      author: json['author'] as String? ?? 'Unknown',
      album: json['album'] as String?,
      files: json['files'] as List<String>? ?? [],
      // duration: (audio['duration'] as num?)?.toDouble() ?? 0,
      durationFormatted:
          audio['durationFormatted'] as String? ?? '00:00:00.000',
      totalChapters: json['totalChapters'] as int? ?? chapters.length,
      chapters: chapters,
    );
  }

  String get fullPath => p.join(path, files.first);

  Map<String, dynamic> toJson() => {
        // 'id': id,
        'path': path,
        'title': title,
        'author': author,
        'album': album,
        'files': files,
        // 'duration': duration,
        'durationFormatted': durationFormatted,
        'totalChapters': totalChapters,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };
}

/// Represents a chapter within an audiobook.
class Chapter {
  final int index;
  final double start;
  final double end;
  final double duration;
  final String startFormatted;
  final String endFormatted;
  final String durationFormatted;
  final String title;
  final String displayTitle;

  const Chapter({
    required this.index,
    required this.start,
    required this.end,
    required this.duration,
    required this.startFormatted,
    required this.endFormatted,
    required this.durationFormatted,
    required this.title,
    required this.displayTitle,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      index: json['index'] as int? ?? 0,
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      startFormatted: json['startFormatted'] as String? ?? '',
      endFormatted: json['endFormatted'] as String? ?? '',
      durationFormatted: json['durationFormatted'] as String? ?? '',
      title: json['title'] as String? ?? '',
      displayTitle: json['displayTitle'] as String? ?? 'Chapter ${json['index']}',
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'start': start,
        'end': end,
        'duration': duration,
        'startFormatted': startFormatted,
        'endFormatted': endFormatted,
        'durationFormatted': durationFormatted,
        'title': title,
        'displayTitle': displayTitle,
      };
}
