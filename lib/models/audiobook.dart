import 'package:path/path.dart' as p;

/// Represents an audiobook with metadata and chapters.
class Audiobook {
  // final String id;
  final String path;
  final String title;
  final String author;
  final String? narrator;
  final String? series;
  final String? seriesSequence;
  final String? description;
  final String? publishYear;
  final List<String> subjects;
  final String? coverPath;
  final bool hasMetadataLocally;
  final List<String> files;
  final String durationFormatted;
  final int totalChapters;
  final List<Chapter> chapters;

  const Audiobook({
    // required this.id,
    required this.path,
    required this.title,
    required this.author,
    this.narrator,
    this.series,
    this.seriesSequence,
    this.description,
    this.publishYear,
    this.subjects = const [],
    this.coverPath,
    this.hasMetadataLocally = false,
    required this.files,
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
      narrator: json['narrator'] as String?,
      series: json['series'] as String? ?? json['album'] as String?,
      seriesSequence: json['seriesSequence'] as String?,
      description: json['description'] as String?,
      publishYear: json['publishYear'] as String?,
      subjects: (json['subjects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coverPath: json['coverPath'] as String?,
      hasMetadataLocally: json['hasMetadataLocally'] as bool? ?? false,
      files: (json['files'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      durationFormatted:
          audio['durationFormatted'] as String? ?? '00:00:00.000',
      totalChapters: json['totalChapters'] as int? ?? chapters.length,
      chapters: chapters,
    );
  }

  Audiobook copyWith({
    String? title,
    String? author,
    String? narrator,
    String? series,
    String? seriesSequence,
    String? description,
    String? publishYear,
    List<String>? subjects,
    String? coverPath,
    bool? hasMetadataLocally,
    List<String>? files,
    String? durationFormatted,
    int? totalChapters,
    List<Chapter>? chapters,
  }) {
    return Audiobook(
      path: path,
      title: title ?? this.title,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      series: series ?? this.series,
      seriesSequence: seriesSequence ?? this.seriesSequence,
      description: description ?? this.description,
      publishYear: publishYear ?? this.publishYear,
      subjects: subjects ?? this.subjects,
      coverPath: coverPath ?? this.coverPath,
      hasMetadataLocally: hasMetadataLocally ?? this.hasMetadataLocally,
      files: files ?? this.files,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      totalChapters: totalChapters ?? this.totalChapters,
      chapters: chapters ?? this.chapters,
    );
  }

  String get fullPath => p.join(path, files.first);

  Map<String, dynamic> toJson() => {
        // 'id': id,
        'path': path,
        'title': title,
        'author': author,
        'narrator': narrator,
        'series': series,
        'seriesSequence': seriesSequence,
        'description': description,
        'publishYear': publishYear,
        'subjects': subjects,
        'coverPath': coverPath,
        'hasMetadataLocally': hasMetadataLocally,
        'files': files,
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
  final String? part;

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
    this.part,
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
      part: json['part'] as String?,
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
        if (part != null) 'part': part,
      };
}
