/// Metadata inferred from the folder path under a library root.
class PathMetadata {
  final String author;
  final String? universe;
  final String? saga;
  final String? era;
  final String bookTitle;
  final String? seriesPosition;

  /// Reading order of the saga within its universe (`02` from `02 - Mistborn`).
  final String? sagaOrder;

  /// Order of this book (or its saga) within the universe
  /// (`01` for Elantris, `02` for all Mistborn books under Cosmere).
  final String? universeOrder;
  final String? publishYear;
  final String? narrator;

  /// Hierarchical order tokens after author/universe
  /// (e.g. Mistborn Era 1 book 01 → `[2, 1, 1]`).
  final List<double> readingOrderKey;

  const PathMetadata({
    required this.author,
    this.universe,
    this.saga,
    this.era,
    required this.bookTitle,
    this.seriesPosition,
    this.sagaOrder,
    this.universeOrder,
    this.publishYear,
    this.narrator,
    this.readingOrderKey = const [],
  });
}

/// A detected audiobook directory with path-derived fields and audio files.
class ScannedBook {
  final String path;
  final String root;
  final List<String> audioFiles;
  final PathMetadata pathMeta;
  final Map<String, dynamic> hierarchy;
  final bool hasMetadataFile;

  const ScannedBook({
    required this.path,
    required this.root,
    required this.audioFiles,
    required this.pathMeta,
    required this.hierarchy,
    required this.hasMetadataFile,
  });

  String get title => (hierarchy['title'] as String?) ?? pathMeta.bookTitle;

  String get author {
    final h = hierarchy['author'] as String?;
    if (h != null && h.isNotEmpty) return h;
    return pathMeta.author;
  }

  String? get universe {
    final h = hierarchy['universe'] as String?;
    if (h != null && h.isNotEmpty) return h;
    return pathMeta.universe;
  }

  String? get series {
    final h = hierarchy['saga'] as String?;
    if (h != null && h.isNotEmpty) return h;
    return pathMeta.saga;
  }

  String? get era {
    final h = hierarchy['era'] as String?;
    if (h != null && h.isNotEmpty) return h;
    return pathMeta.era;
  }
}

/// A disc/CD/part belonging to a parent audiobook.
class BookPart {
  final String name;
  final String path;
  final String? durationFormatted;
  final List<String> audioFiles;

  /// Playback/reading order within the book (prologue=0, CD1=1, epilogue=10000…).
  final int? order;

  const BookPart({
    required this.name,
    required this.path,
    this.durationFormatted,
    this.audioFiles = const [],
    this.order,
  });

  factory BookPart.fromJson(Map<String, dynamic> json) {
    final filesRaw = json['audioFiles'];
    final orderRaw = json['order'] ?? json['readingOrder'];
    return BookPart(
      name: json['name']?.toString() ?? json['partName']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      durationFormatted: json['durationFormatted']?.toString(),
      audioFiles: filesRaw is List
          ? filesRaw.map((e) => e.toString()).toList()
          : const [],
      order: orderRaw is int
          ? orderRaw
          : int.tryParse(orderRaw?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    if (order != null) 'order': order,
    if (durationFormatted != null && durationFormatted!.isNotEmpty)
      'durationFormatted': durationFormatted,
    if (audioFiles.isNotEmpty) 'audioFiles': audioFiles,
  };

  BookPart copyWith({
    String? name,
    String? path,
    String? durationFormatted,
    List<String>? audioFiles,
    int? order,
  }) {
    return BookPart(
      name: name ?? this.name,
      path: path ?? this.path,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      audioFiles: audioFiles ?? this.audioFiles,
      order: order ?? this.order,
    );
  }
}

/// Normalized book.metadata.json content.
class BookMetadata {
  String title;
  String author;
  String? narrator;
  String? universe;
  String? seriesName;
  String? seriesPosition;

  /// Order of this entry within its universe (`02` for Mistborn under Cosmere).
  String? universeOrder;
  String? era;
  List<double> readingOrderKey;
  String? description;
  String? publishYear;
  List<String> subjects;
  String durationFormatted;
  List<dynamic> chapters;
  List<BookPart> parts;

  /// Editing-only: `book` or `part`. Persisted books are always stored as books;
  /// parts are recorded under the parent book's [parts] list.
  String entryType;

  /// Parent book title when editing a mis-detected part folder.
  String? partOf;

  /// Label for this part (e.g. CD1, Disc 2).
  String? partName;

  /// Fields the user intentionally left blank (written as "" in JSON).
  Set<String> blankKeys;

  BookMetadata({
    required this.title,
    required this.author,
    this.narrator,
    this.universe,
    this.seriesName,
    this.seriesPosition,
    this.universeOrder,
    this.era,
    List<double>? readingOrderKey,
    this.description,
    this.publishYear,
    List<String>? subjects,
    this.durationFormatted = '00:00:00.000',
    List<dynamic>? chapters,
    List<BookPart>? parts,
    this.entryType = 'book',
    this.partOf,
    this.partName,
    Set<String>? blankKeys,
  }) : readingOrderKey = readingOrderKey ?? const [],
       subjects = subjects ?? [],
       chapters = chapters ?? [],
       parts = parts ?? [],
       blankKeys = blankKeys ?? {};

  bool get isPart => entryType == 'part';

  static const clearableKeys = {
    'universe',
    'seriesName',
    'seriesPosition',
    'universeOrder',
    'narrator',
    'partOf',
    'partName',
  };

  static String normalizeEntryType(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    if (v == 'part' ||
        v == 'parte' ||
        v == 'disc' ||
        v == 'disco' ||
        v == 'cd') {
      return 'part';
    }
    return 'book';
  }

  void clearField(String key) {
    switch (key) {
      case 'universe':
        universe = null;
        break;
      case 'seriesName':
        seriesName = null;
        break;
      case 'seriesPosition':
        seriesPosition = null;
        break;
      case 'universeOrder':
        universeOrder = null;
        break;
      case 'narrator':
        narrator = null;
        break;
      case 'partOf':
        partOf = null;
        break;
      case 'partName':
        partName = null;
        break;
      default:
        return;
    }
    blankKeys.add(key);
  }

  void setClearable(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      clearField(key);
      return;
    }
    blankKeys.remove(key);
    switch (key) {
      case 'universe':
        universe = trimmed;
        break;
      case 'seriesName':
        seriesName = trimmed;
        break;
      case 'seriesPosition':
        seriesPosition = trimmed;
        break;
      case 'universeOrder':
        universeOrder = trimmed;
        break;
      case 'narrator':
        narrator = trimmed;
        break;
      case 'partOf':
        partOf = trimmed;
        break;
      case 'partName':
        partName = trimmed;
        break;
    }
  }

  void upsertPart(BookPart part) {
    final idx = parts.indexWhere(
      (p) =>
          p.path == part.path ||
          (p.name.isNotEmpty &&
              part.name.isNotEmpty &&
              p.name.toLowerCase() == part.name.toLowerCase()),
    );
    if (idx == -1) {
      parts.add(part);
    } else {
      final existing = parts[idx];
      parts[idx] = part.copyWith(
        order: part.order ?? existing.order,
        durationFormatted: part.durationFormatted ?? existing.durationFormatted,
        audioFiles: part.audioFiles.isNotEmpty
            ? part.audioFiles
            : existing.audioFiles,
      );
    }
    sortParts();
  }

  void sortParts() {
    parts.sort(comparePartsByOrder);
  }

  static int comparePartsByOrder(BookPart a, BookPart b) {
    const unset = 1 << 30;
    final byOrder = (a.order ?? unset).compareTo(b.order ?? unset);
    if (byOrder != 0) return byOrder;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// JSON for a real audiobook (never persists entryType=part).
  Map<String, dynamic> toJson() {
    String? jsonClearable(String key, String? value) {
      if (blankKeys.contains(key)) return '';
      if (value != null && value.isNotEmpty) return value;
      return null;
    }

    final universeJson = jsonClearable('universe', universe);
    final seriesJson = jsonClearable('seriesName', seriesName);
    final posJson = jsonClearable('seriesPosition', seriesPosition);
    final universeOrderJson = jsonClearable('universeOrder', universeOrder);
    final narratorJson = jsonClearable('narrator', narrator);

    return {
      'title': title,
      'author': author,
      'entryType': 'book',
      'narrator': ?narratorJson,
      'universe': ?universeJson,
      'seriesName': ?seriesJson,
      'seriesPosition': ?posJson,
      'universeOrder': ?universeOrderJson,
      if (era != null && era!.isNotEmpty) 'era': era,
      if (readingOrderKey.isNotEmpty) 'readingOrderKey': readingOrderKey,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (publishYear != null && publishYear!.isNotEmpty)
        'publishYear': publishYear,
      'subjects': subjects,
      'durationFormatted': durationFormatted,
      'chapters': chapters,
      if (parts.isNotEmpty) 'parts': parts.map((p) => p.toJson()).toList(),
    };
  }

  BookMetadata copy() => BookMetadata(
    title: title,
    author: author,
    narrator: narrator,
    universe: universe,
    seriesName: seriesName,
    seriesPosition: seriesPosition,
    universeOrder: universeOrder,
    era: era,
    readingOrderKey: List<double>.from(readingOrderKey),
    description: description,
    publishYear: publishYear,
    subjects: List<String>.from(subjects),
    durationFormatted: durationFormatted,
    chapters: List<dynamic>.from(chapters),
    parts: List<BookPart>.from(parts),
    entryType: entryType,
    partOf: partOf,
    partName: partName,
    blankKeys: Set<String>.from(blankKeys),
  );
}

/// Online enrichment result (non-destructive fill-ins).
class OnlineEnrichment {
  final String? description;
  final String? publishYear;
  final String? seriesName;
  final String? seriesPosition;
  final List<String> subjects;
  final String? coverUrl;

  const OnlineEnrichment({
    this.description,
    this.publishYear,
    this.seriesName,
    this.seriesPosition,
    this.subjects = const [],
    this.coverUrl,
  });
}
