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

  /// Parses a relative path using segment mapping, custom regex rules, or default tokenization.
  DirPathMetadata parsePath(String relativePath) {
    final segments = relativePath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return const DirPathMetadata(author: 'Unknown', bookTitle: 'Unknown');
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
            saga = val;
            break;
          case PathSegmentRole.era:
            era = val;
            break;
          case PathSegmentRole.bookTitle:
            bookTitle = val;
            break;
          case PathSegmentRole.part:
            narrator = val;
            break;
          case PathSegmentRole.ignore:
            break;
        }
      }
      return DirPathMetadata(
        author: author,
        universe: universe,
        saga: saga,
        era: era,
        bookTitle: bookTitle,
        narrator: narrator,
      );
    }

    // Default folder structure parsing: Author / [Universe /] [Saga /] BookTitle
    if (segments.length == 1) {
      return DirPathMetadata(author: 'Unknown', bookTitle: segments[0]);
    } else if (segments.length == 2) {
      return DirPathMetadata(author: segments[0], bookTitle: segments[1]);
    } else if (segments.length == 3) {
      return DirPathMetadata(author: segments[0], saga: segments[1], bookTitle: segments[2]);
    } else {
      return DirPathMetadata(
        author: segments[0],
        universe: segments[1],
        saga: segments[2],
        bookTitle: segments.last,
      );
    }
  }
}
