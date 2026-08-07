

class Ebook {
  final String path;
  final String title;
  final String author;
  final String? universe;
  final String? series;
  final String? seriesSequence;
  final String? description;
  final String? publishYear;
  final String? coverPath;
  final String file; // Path to the actual .epub or .pdf file
  final bool isRead;
  final bool hasMetadataLocally;

  const Ebook({
    required this.path,
    required this.title,
    required this.author,
    this.universe,
    this.series,
    this.seriesSequence,
    this.description,
    this.publishYear,
    this.coverPath,
    required this.file,
    this.isRead = false,
    this.hasMetadataLocally = false,
  });

  Ebook copyWith({
    String? path,
    String? title,
    String? author,
    String? universe,
    String? series,
    String? seriesSequence,
    String? description,
    String? publishYear,
    String? coverPath,
    String? file,
    bool? isRead,
    bool? hasMetadataLocally,
  }) {
    return Ebook(
      path: path ?? this.path,
      title: title ?? this.title,
      author: author ?? this.author,
      universe: universe ?? this.universe,
      series: series ?? this.series,
      seriesSequence: seriesSequence ?? this.seriesSequence,
      description: description ?? this.description,
      publishYear: publishYear ?? this.publishYear,
      coverPath: coverPath ?? this.coverPath,
      file: file ?? this.file,
      isRead: isRead ?? this.isRead,
      hasMetadataLocally: hasMetadataLocally ?? this.hasMetadataLocally,
    );
  }

  factory Ebook.fromJson(Map<String, dynamic> json, String basePath) {
    final rawUniverse = json['universe'] as String?;
    return Ebook(
      path: basePath,
      title: json['title'] as String? ?? 'Unknown',
      author: json['author'] as String? ?? 'Unknown',
      universe: rawUniverse != null && rawUniverse.trim().isNotEmpty
          ? rawUniverse.trim()
          : null,
      series: json['series'] as String?,
      seriesSequence: json['seriesSequence'] as String?,
      description: json['description'] as String?,
      publishYear: json['publishYear'] as String?,
      coverPath: json['coverPath'] as String?,
      file: json['file'] as String,
      isRead: json['isRead'] as bool? ?? false,
      hasMetadataLocally: json['hasMetadataLocally'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'author': author,
        'universe': universe,
        'series': series,
        'seriesSequence': seriesSequence,
        'description': description,
        'publishYear': publishYear,
        'coverPath': coverPath,
        'file': file,
        'isRead': isRead,
        'hasMetadataLocally': hasMetadataLocally,
      };

  bool get isPdf => file.toLowerCase().endsWith('.pdf');
  bool get isEpub => file.toLowerCase().endsWith('.epub');
}
