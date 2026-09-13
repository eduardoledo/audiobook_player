import '../models/path_pattern_rule.dart';
export '../models/path_pattern_rule.dart' show PathSegmentRole;

/// User-configured positional mapping rule for folder segments.
class SegmentPathMapping {
  final List<PathSegmentRole> segmentRoles;

  const SegmentPathMapping({required this.segmentRoles});
}

/// Extracted metadata from a directory path relative to the scan root.
class DirPathMetadata {
  final String author;
  final String? universe;
  final String? saga;
  final String? era;
  final String bookTitle;
  final String? publishYear;
  final String? narrator;
  final String? seriesSequence;
  final String? universeOrder;
  final List<double> readingOrderKey;

  const DirPathMetadata({
    required this.author,
    this.universe,
    this.saga,
    this.era,
    required this.bookTitle,
    this.publishYear,
    this.narrator,
    this.seriesSequence,
    this.universeOrder,
    this.readingOrderKey = const [],
  });
}

/// Deep domain service for path metadata parsing and folder classification.
class PathMetadataParser {
  final List<PathPatternRule> customRules;
  final SegmentPathMapping? segmentMapping;

  const PathMetadataParser({
    this.customRules = const [],
    this.segmentMapping,
  });

  /// Determines if a folder name represents a Saga Era (e.g. `Era 1`).
  static bool looksLikeEraFolder(String name) {
    final n = name.trim();
    return RegExp(
      r'^(?:eras?|era)\s*[\s._|-]*\s*(?:\d+|[a-zA-Z][a-zA-Z0-9_-]*)$',
      caseSensitive: false,
    ).hasMatch(n);
  }

  /// Determines if a folder name represents a disc/part/prologue of a single book.
  static bool looksLikeDiscPartFolder(String name) {
    final n = name.trim();
    if (looksLikeEraFolder(n)) return false;
    if (RegExp(
      r'^(cd|disc|disk|part|parte|disco|libro|acto|act|vol|volume|tomo|chapter|capitulo|capítulo|section|seccion|sección|ch|cap)[\s._|-]*\d+',
      caseSensitive: false,
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(cd|disc|disk|part|parte|disco|libro|acto|act|vol|volume|tomo|chapter|capitulo|capítulo|section|seccion|sección)[\s|_-]+[a-zA-Z0-9_-]+$',
      caseSensitive: false,
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(?:\d{1,3}\s*[-.|:_)\s]+)?(?:part|parte|chapter|capitulo|capítulo|section|seccion|sección)\s+(?:[ivxlcdm]+|\d+)\b',
      caseSensitive: false,
    ).hasMatch(n)) {
      return true;
    }
    if (_looksLikePrologueOrEpilogueFolder(n)) return true;
    if (RegExp(
      r'^(?:[A-Za-z0-9]{1,4}\s*[-.|:_)\s]+)'
      r'(?:pr[oó]logo|prologue|ep[ií]logo|epilogue|intro(?:duction)?|proem|preface|foreword)\b',
      caseSensitive: false,
    ).hasMatch(n)) {
      return true;
    }
    return RegExp(r'^\d{1,3}$').hasMatch(n);
  }

  static bool looksLikePartFolder(String name) {
    return looksLikeEraFolder(name) || looksLikeDiscPartFolder(name);
  }

  static bool _looksLikePrologueOrEpilogueFolder(String name) {
    return RegExp(
      r'^(?:'
      r'(?:[A-Za-z0-9]{1,4}\s*[-._)\s]+)?'
      r'(?:pr[oó]logo|prologue|ep[ií]logo|epilogue|intro(?:duction)?|proem|preface|foreword)'
      r'|'
      r'(?:pr[oó]logo|prologue|ep[ií]logo|epilogue|intro(?:duction)?|proem|preface|foreword)'
      r'(?:\s*[-._)\s]*\d{1,3})?'
      r')$',
      caseSensitive: false,
    ).hasMatch(name.trim());
  }

  /// Sort order of a part folder within a book.
  static int? partOrderFromFolderName(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;

    final isPrologue = RegExp(
      r'pr[oó]logo|prologue|intro(?:duction)?|proem|preface|foreword',
      caseSensitive: false,
    ).hasMatch(n);
    final isEpilogue =
        RegExp(r'ep[ií]logo|epilogue', caseSensitive: false).hasMatch(n);

    final partNum = RegExp(
      r'(?:cd|disc|disk|part|parte|disco|libro|era|eras|acto|act|vol|volume|tomo|chapter|capitulo|capítulo|section|seccion|sección|ch|cap)'
      r'[\s._|-]*(\d{1,4}|[ivxlcdm]+)\b',
      caseSensitive: false,
    ).firstMatch(n);
    int? base;
    if (partNum != null) {
      final raw = partNum.group(1)!;
      base = int.tryParse(raw) ?? _romanToInt(raw);
    }
    base ??= () {
      final numMatch = RegExp(r'(\d{1,4})').firstMatch(n);
      return numMatch != null ? int.tryParse(numMatch.group(1)!) : null;
    }();

    if (isPrologue) return base ?? 0;
    if (isEpilogue) return 10000 + (base ?? 0);
    return base;
  }

  static int? _romanToInt(String roman) {
    const values = <String, int>{
      'i': 1,
      'v': 5,
      'x': 10,
      'l': 50,
      'c': 100,
      'd': 500,
      'm': 1000,
    };
    final s = roman.toLowerCase().trim();
    if (s.isEmpty || !RegExp(r'^[ivxlcdm]+$').hasMatch(s)) return null;
    var total = 0;
    var prev = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      final v = values[s[i]]!;
      if (v < prev) {
        total -= v;
      } else {
        total += v;
        prev = v;
      }
    }
    return total > 0 ? total : null;
  }

  static final RegExp _narratorParen = RegExp(
    r'\(\s*(?:[A-Za-z]{1,8}\d{1,3}\s*[-–—:]\s*)?'
    r'(?:read|narrated|performed|voiced|told)\s+by\s+([^)]+?)\s*\)',
    caseSensitive: false,
  );

  static String? publishYearFromPath(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    final curly = RegExp(r'\{\s*((?:19|20)\d{2})\s*\}').firstMatch(t);
    if (curly != null) return curly.group(1);

    final labeled = RegExp(
      r'\(\s*(?:year|año)\s+((?:19|20)\d{2})\s*\)',
      caseSensitive: false,
    ).firstMatch(t);
    if (labeled != null) return labeled.group(1);

    final bracket = RegExp(r'\[\s*((?:19|20)\d{2})\s*\]').firstMatch(t);
    if (bracket != null) return bracket.group(1);

    final paren = RegExp(r'\(\s*((?:19|20)\d{2})\s*\)').firstMatch(t);
    if (paren != null) return paren.group(1);

    final authorYear =
        RegExp(r'\[\s*[^\]]*?\.((?:19|20)\d{2})\s*\]').firstMatch(t);
    if (authorYear != null) return authorYear.group(1);

    final unclosed = RegExp(r'\[\s*((?:19|20)\d{2})\s*(?=\()').firstMatch(t);
    if (unclosed != null) return unclosed.group(1);

    final delimited = RegExp(r'(?:[._])((?:19|20)\d{2})(?:[._])').firstMatch(t);
    if (delimited != null) return delimited.group(1);

    final leading = RegExp(
      r'^\s*((?:19|20)\d{2})\s*[-–—.:_|]\s+\S',
    ).firstMatch(t);
    if (leading != null) return leading.group(1);

    return null;
  }

  static bool hasMultiplePublishYearsInPath(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final matches = RegExp(r'\b(?:19|20)\d{2}\b').allMatches(t);
    return matches.length > 1;
  }

  static String stripPublishYearFromTitle(String title) {
    var t = title.trim();
    if (t.isEmpty) return t;

    t = t.replaceAll(RegExp(r'\s*\{\s*(?:19|20)\d{2}\s*\}\s*'), ' ');
    t = t.replaceAll(
      RegExp(r'\s*\(\s*(?:year|año)\s+(?:19|20)\d{2}\s*\)\s*', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(RegExp(r'\s*\[\s*[^\]]*?\.((?:19|20)\d{2})\s*\]\s*'), ' ');
    t = t.replaceAll(RegExp(r'\s*\[\s*(?:19|20)\d{2}\s*\]\s*'), ' ');
    t = t.replaceAll(RegExp(r'\s*\(\s*(?:19|20)\d{2}\s*\)\s*'), ' ');
    t = t.replaceAll(RegExp(r'\s*\[\s*(?:19|20)\d{2}\s*(?=\()'), ' ');
    t = t.replaceAll(RegExp(r'(?:[._])(?:19|20)\d{2}(?:[._])'), ' ');
    t = t.replaceFirst(RegExp(r'^\s*(?:19|20)\d{2}\s*[-–—.:_|]\s*'), '');

    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\s*-\s*(?=\()'), ' ');
    t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
    t = t.replaceAll(RegExp(r'^\s*-\s*'), '');
    return t.trim();
  }

  static String? narratorFromPath(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final m = _narratorParen.firstMatch(t);
    if (m == null) return null;
    final name = m.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static String stripNarratorFromTitle(String title) {
    var t = title.trim();
    if (t.isEmpty) return t;

    t = t.replaceAll(_narratorParen, ' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
    t = t.replaceAll(RegExp(r'^\s*-\s*'), '');
    t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
    return t.trim();
  }

  static double? orderTokenFromSegment(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (RegExp(r'^\s*(?:19|20)\d{2}\b').hasMatch(n)) return null;
    final tight = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*[-_]\s*\S').firstMatch(n);
    if (tight != null) return double.tryParse(tight.group(1)!);
    final prefix = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*[._\)|:]\s+\S').firstMatch(n);
    if (prefix != null) return double.tryParse(prefix.group(1)!);
    final pipe = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*[|]\s*\S').firstMatch(n);
    if (pipe != null) return double.tryParse(pipe.group(1)!);
    final keyword = RegExp(
      r'(?:era|eras|part|parte|act|acto|vol|volume|tomo|libro|cd|disc|disk|disco)'
      r'[\s._|-]*(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
    ).firstMatch(n);
    if (keyword != null) return double.tryParse(keyword.group(1)!);
    return null;
  }

  static String stripOrderPrefix(String name) {
    var t = name.trim();
    t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[-_]\s*'), '');
    t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[._\)|:]\s+'), '');
    t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[|]\s*'), '');
    return t.trim();
  }

  static String? rawOrderPrefix(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (RegExp(r'^\s*(?:19|20)\d{2}\b').hasMatch(n)) return null;
    final m = RegExp(
      r'^\s*(\d+(?:\.\d+)?)\s*(?:[-_]\s*|[._\)|:]\s+|[|]\s+)',
    ).firstMatch(n);
    if (m == null || orderTokenFromSegment(n) == null) return null;
    return m.group(1);
  }

  /// Parses a relative path using segment mapping, custom regex rules, or default tokenization.
  DirPathMetadata parsePath(String relativePath) {
    final segments = relativePath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return const DirPathMetadata(author: 'Unknown', bookTitle: 'Unknown');
    }

    String sanitizeTitle(String title, {bool stripOrder = false}) {
      var t = title;
      final year = publishYearFromPath(t);
      if (year != null) {
        t = stripPublishYearFromTitle(t);
      }
      final narrator = narratorFromPath(t);
      if (narrator != null) {
        t = stripNarratorFromTitle(t);
      }
      if (stripOrder) {
        final pos = rawOrderPrefix(t);
        if (pos != null) {
          t = stripOrderPrefix(t);
        }
      }
      return t.trim();
    }

    // Apply manual positional segment mapping if provided
    if (segmentMapping != null && segmentMapping!.segmentRoles.isNotEmpty) {
      String author = 'Unknown';
      String? universe;
      String? saga;
      String? era;
      String bookTitle = segments.last;
      String? narrator;

      for (int i = 0; i < segments.length && i < segmentMapping!.segmentRoles.length; i++) {
        final val = segments[i];
        switch (segmentMapping!.segmentRoles[i]) {
          case PathSegmentRole.author:
            author = val;
            break;
          case PathSegmentRole.universe:
            universe = val;
            break;
          case PathSegmentRole.saga:
            saga = sanitizeTitle(val);
            break;
          case PathSegmentRole.era:
            era = val;
            break;
          case PathSegmentRole.bookTitle:
            bookTitle = val;
            break;
          case PathSegmentRole.part:
            break;
          case PathSegmentRole.ignore:
            break;
        }
      }

      final extractedYear = publishYearFromPath(relativePath) ?? publishYearFromPath(segments.last);
      final extractedNarrator = narrator ?? narratorFromPath(relativePath) ?? narratorFromPath(segments.last);
      final cleanTitle = sanitizeTitle(bookTitle, stripOrder: true);

      return DirPathMetadata(
        author: author,
        universe: universe,
        saga: saga,
        era: era,
        bookTitle: cleanTitle.isEmpty ? bookTitle : cleanTitle,
        publishYear: extractedYear,
        narrator: extractedNarrator,
      );
    }

    String author = 'Unknown';
    String? universe;
    String? saga;
    String? era;
    String rawTitle = segments.last;

    if (segments.length == 1) {
      rawTitle = segments[0];
    } else if (segments.length == 2) {
      author = segments[0];
      rawTitle = segments[1];
    } else if (segments.length == 3) {
      author = segments[0];
      saga = sanitizeTitle(segments[1]);
      rawTitle = segments[2];
    } else {
      author = segments[0];
      universe = segments[1];
      saga = sanitizeTitle(segments[2]);
      rawTitle = segments.last;
    }

    final extractedYear = publishYearFromPath(relativePath) ?? publishYearFromPath(rawTitle);
    final extractedNarrator = narratorFromPath(relativePath) ?? narratorFromPath(rawTitle);
    final cleanTitle = sanitizeTitle(rawTitle, stripOrder: true);

    String? finalUniverse = universe;
    String? finalSaga = saga;
    String? finalEra = era;

    final authorLower = author.toLowerCase().trim();
    if (finalUniverse != null && finalUniverse.toLowerCase().trim() == authorLower) {
      finalUniverse = null;
    }
    final parentLevels = [
      authorLower,
      if (finalUniverse != null) finalUniverse.toLowerCase().trim(),
    ];

    if (finalSaga != null && parentLevels.contains(finalSaga.toLowerCase().trim())) {
      finalSaga = null;
    }
    if (finalSaga != null) {
      parentLevels.add(finalSaga.toLowerCase().trim());
    }

    if (finalEra != null && parentLevels.contains(finalEra.toLowerCase().trim())) {
      finalEra = null;
    }

    return DirPathMetadata(
      author: author,
      universe: finalUniverse,
      saga: finalSaga,
      era: finalEra,
      bookTitle: cleanTitle.isEmpty ? rawTitle : cleanTitle,
      publishYear: extractedYear,
      narrator: extractedNarrator,
    );
  }
}
