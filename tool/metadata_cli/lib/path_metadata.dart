import 'package:path/path.dart' as p;

import 'models.dart';

String? nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// True for saga "era" folders (`Era 1`, `Eras 2`) — not disc/CD parts.
bool looksLikeEraFolder(String name) {
  final n = name.trim();
  return RegExp(
    r'^(?:eras?|era)\s*[\s._|-]*\s*(?:\d+|[a-zA-Z][a-zA-Z0-9_-]*)$',
    caseSensitive: false,
  ).hasMatch(n);
}

/// Disc/CD/part/prologue folders that belong to a single multipart book.
/// Excludes saga [looksLikeEraFolder] containers.
bool looksLikeDiscPartFolder(String name) {
  final n = name.trim();
  if (looksLikeEraFolder(n)) return false;
  if (RegExp(
    r'^(cd|disc|disk|part|parte|disco|libro|acto|act|vol|volume|tomo)[\s._|-]*\d+',
    caseSensitive: false,
  ).hasMatch(n)) {
    return true;
  }
  if (RegExp(
    r'^(cd|disc|disk|part|parte|disco|libro|acto|act|vol|volume|tomo)[\s|_-]+[a-zA-Z0-9_-]+$',
    caseSensitive: false,
  ).hasMatch(n)) {
    return true;
  }
  if (RegExp(
    r'^(?:\d{1,3}\s*[-.|:_)\s]+)?(?:part|parte)\s+(?:[ivxlcdm]+|\d+)\b',
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

/// Part/disc/era/prologue/epilogue folder (eras + disc parts).
bool looksLikePartFolder(String name) {
  return looksLikeEraFolder(name) || looksLikeDiscPartFolder(name);
}

bool _looksLikePrologueOrEpilogueFolder(String name) {
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

/// Leading or keyword order token from a folder/file segment (`02`, `0.5`, `Era 1` → 1).
///
/// Accepts both spaced and tight hyphen/underscore forms:
/// `02 - Title`, `02-Title`, `02_Title`. Dot/colon/paren still require a space
/// after the separator so values like `3.14` are not treated as order `3`.
double? orderTokenFromSegment(String name) {
  final n = name.trim();
  if (n.isEmpty) return null;
  if (RegExp(r'^\s*(?:19|20)\d{2}\b').hasMatch(n)) {
    // Year prefixes are not reading-order tokens.
    return null;
  }
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

/// Strips a leading reading-order prefix (`02 - Mistborn` / `02-Title` → title).
String stripOrderPrefix(String name) {
  var t = name.trim();
  t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[-_]\s*'), '');
  t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[._\)|:]\s+'), '');
  t = t.replaceFirst(RegExp(r'^\s*\d+(?:\.\d+)?\s*[|]\s*'), '');
  return t.trim();
}

/// Captures the raw order spelling (`01`, `0.5`) from a numbered prefix.
String? rawOrderPrefix(String name) {
  final n = name.trim();
  if (n.isEmpty) return null;
  if (RegExp(r'^\s*(?:19|20)\d{2}\b').hasMatch(n)) return null;
  final m = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*(?:[-_]\s*|[._\)|:]\s+|[|]\s+)',
  ).firstMatch(n);
  if (m == null) return null;
  if (orderTokenFromSegment(n) == null) return null;
  return m.group(1);
}

/// Lexicographic compare of hierarchical reading-order keys.
///
/// Shorter shared prefix comes first (`[2]` before `[2, 1]`), so a standalone
/// numbered item sorts before expanding into a saga with the same index —
/// but saga books share the saga's leading token and sort as a contiguous block.
int compareReadingOrderKeys(List<double> a, List<double> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final cmp = a[i].compareTo(b[i]);
    if (cmp != 0) return cmp;
  }
  return a.length.compareTo(b.length);
}

/// Sort order of a part folder within a book.
///
/// - Prólogo / Prologue → `0` (or the explicit number if present)
/// - CD1 / Disc 2 / 01 / Parte III / Part I → the extracted number
/// - Epílogo / Epilogue → `10000` (+ number if present, e.g. Epílogo 2 → 10002)
/// - Unknown → `null` (sorted after numbered parts, by name)
int? partOrderFromFolderName(String name) {
  final n = name.trim();
  if (n.isEmpty) return null;

  final isPrologue =
      RegExp(
        r'pr[oó]logo|prologue|intro(?:duction)?|proem|preface|foreword',
        caseSensitive: false,
      ).hasMatch(n);
  final isEpilogue =
      RegExp(r'ep[ií]logo|epilogue', caseSensitive: false).hasMatch(n);

  // Prefer Part/CD roman or number over a leading folder index when both exist
  // ("01 - Part I" → 1 from Part I, not only from 01).
  final partNum = RegExp(
    r'(?:cd|disc|disk|part|parte|disco|libro|era|eras|acto|act|vol|volume|tomo)'
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

int? _romanToInt(String roman) {
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

/// Extracts a publication year (19xx/20xx) from a path segment or title.
///
/// Variants seen in libraries:
/// - `[1976]`, `[1990 ]`, `[1989]`
/// - `(2014)`, `(2018)`
/// - `[1998 (` (unclosed bracket before another group)
/// - `1973 - The Matlock Paper` (leading year)
/// - `[Jeff Lindsay.2004]` (author.year inside brackets)
String? publishYearFromPath(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;

  // [1990 ] / [1976]
  final bracket = RegExp(r'\[\s*((?:19|20)\d{2})\s*\]').firstMatch(t);
  if (bracket != null) return bracket.group(1);

  // (2014) — year alone inside parentheses
  final paren = RegExp(r'\(\s*((?:19|20)\d{2})\s*\)').firstMatch(t);
  if (paren != null) return paren.group(1);

  // [Jeff Lindsay.2004]
  final authorYear = RegExp(r'\[\s*[^\]]*?\.((?:19|20)\d{2})\s*\]').firstMatch(t);
  if (authorYear != null) return authorYear.group(1);

  // [1998 (NV1 …) — year in unclosed bracket
  final unclosed = RegExp(r'\[\s*((?:19|20)\d{2})\s*(?=\()').firstMatch(t);
  if (unclosed != null) return unclosed.group(1);

  // 1973 - Title / 2021 - Project Hail Mary
  final leading = RegExp(
    r'^\s*((?:19|20)\d{2})\s*[-–—.:_|]\s+\S',
  ).firstMatch(t);
  if (leading != null) return leading.group(1);

  return null;
}

/// Removes year markers from a title after [publishYearFromPath] extraction.
String stripPublishYearFromTitle(String title) {
  var t = title.trim();
  if (t.isEmpty) return t;

  // [Jeff Lindsay.2004]
  t = t.replaceAll(RegExp(r'\s*\[\s*[^\]]*?\.((?:19|20)\d{2})\s*\]\s*'), ' ');
  // [1990 ] / [1976]
  t = t.replaceAll(RegExp(r'\s*\[\s*(?:19|20)\d{2}\s*\]\s*'), ' ');
  // (2014)
  t = t.replaceAll(RegExp(r'\s*\(\s*(?:19|20)\d{2}\s*\)\s*'), ' ');
  // [1998 (
  t = t.replaceAll(RegExp(r'\s*\[\s*(?:19|20)\d{2}\s*(?=\()'), ' ');
  // Leading year prefix
  t = t.replaceFirst(RegExp(r'^\s*(?:19|20)\d{2}\s*[-–—.:_|]\s*'), '');

  t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
  t = t.replaceAll(RegExp(r'\s*-\s*(?=\()'), ' ');
  t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
  t = t.replaceAll(RegExp(r'^\s*-\s*'), '');
  return t.trim();
}

/// Parenthetical narrator markers seen in libraries, e.g.:
/// - `(read by Bob Askey)`
/// - `(VC1 - read by Frank Muller)`
/// - `(B1 - read by George Holmes)`
final RegExp _narratorParen = RegExp(
  r'\(\s*(?:[A-Za-z]{1,8}\d{1,3}\s*[-–—:]\s*)?'
  r'(?:read|narrated|performed|voiced|told)\s+by\s+([^)]+?)\s*\)',
  caseSensitive: false,
);

/// Extracts narrator name from a path segment or title.
String? narratorFromPath(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final m = _narratorParen.firstMatch(t);
  if (m == null) return null;
  final name = m.group(1)?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Removes narrator markers from a title after [narratorFromPath] extraction.
String stripNarratorFromTitle(String title) {
  var t = title.trim();
  if (t.isEmpty) return t;

  t = t.replaceAll(_narratorParen, ' ');
  t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
  t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
  t = t.replaceAll(RegExp(r'^\s*-\s*'), '');
  t = t.replaceAll(RegExp(r'\s*-\s*$'), '');
  return t.trim();
}

/// Parses book [dirPath] relative to [baseDirectoryPath] for Author/Universe/Saga/Title.
///
/// Supports Cosmere-style trees:
/// `Author/Universe/02 - Mistborn/Era 1/01 - The Final Empire`
/// → author, universe=Cosmere, saga=Mistborn (order 02), era=Era 1, book order 01.
PathMetadata? parseDirPath(String dirPath, String baseDirectoryPath) {
  final base = p.normalize(baseDirectoryPath);
  final dir = p.normalize(dirPath);
  if (!dir.startsWith(base) || dir == base) return null;
  final relative =
      dir.substring(base.endsWith(p.separator) ? base.length : base.length + 1);
  final segments = p.split(relative).where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  String? seriesPositionFromTitle(String title) {
    final token = orderTokenFromSegment(title);
    if (token == null) return null;
    // Prefer the original spelling (`01`, `0.5`) when present as a prefix.
    return rawOrderPrefix(title) ??
        (token == token.truncateToDouble()
            ? token.toInt().toString()
            : token.toString());
  }

  PathMetadata build({
    required String author,
    String? universe,
    String? saga,
    String? era,
    required String bookTitle,
    List<String> orderSegments = const [],
  }) {
    final year = publishYearFromPath(bookTitle);
    var cleanTitle =
        year != null ? stripPublishYearFromTitle(bookTitle) : bookTitle;
    final narrator = narratorFromPath(cleanTitle) ?? narratorFromPath(bookTitle);
    if (narrator != null) {
      cleanTitle = stripNarratorFromTitle(cleanTitle);
    }

    // "1973 - Title" is a year prefix, not series position 1973.
    final startsWithYear = RegExp(r'^\s*(?:19|20)\d{2}\b').hasMatch(bookTitle);
    final pos =
        startsWithYear ? null : seriesPositionFromTitle(cleanTitle);
    if (pos != null) {
      cleanTitle = stripOrderPrefix(cleanTitle);
    }

    String? cleanSaga = nonEmpty(saga);
    String? sagaOrder;
    if (cleanSaga != null) {
      sagaOrder = orderTokenFromSegment(cleanSaga)?.toString();
      // Prefer original token spelling from the segment.
      final rawOrder = RegExp(r'^\s*(\d+(?:\.\d+)?)')
          .firstMatch(cleanSaga)
          ?.group(1);
      if (rawOrder != null && orderTokenFromSegment(cleanSaga) != null) {
        sagaOrder = rawOrder;
      }
      final stripped = stripOrderPrefix(cleanSaga);
      if (stripped.isNotEmpty) cleanSaga = stripped;
    }

    String? cleanEra = nonEmpty(era);
    if (cleanEra != null) {
      // Keep display label (`Era 1`); order lives in readingOrderKey.
    }

    final key = <double>[];
    for (final seg in orderSegments) {
      final token = orderTokenFromSegment(seg);
      if (token != null) key.add(token);
    }

    // Order within the universe: saga index when nested, else the book index
    // (Elantris → 01, Mistborn books → 02).
    String? universeOrder = sagaOrder;
    if (universeOrder == null && orderSegments.isNotEmpty) {
      for (final seg in orderSegments) {
        final raw = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(seg)?.group(1);
        if (raw != null && orderTokenFromSegment(seg) != null) {
          universeOrder = raw;
          break;
        }
      }
    }
    universeOrder ??= pos;

    return PathMetadata(
      author: author,
      universe: nonEmpty(universe),
      saga: cleanSaga,
      era: cleanEra,
      bookTitle: cleanTitle.isEmpty ? bookTitle : cleanTitle,
      seriesPosition: pos,
      sagaOrder: sagaOrder,
      universeOrder: universeOrder,
      publishYear: year,
      narrator: narrator,
      readingOrderKey: key,
    );
  }

  if (segments.length == 1) {
    return build(
      author: 'Unknown',
      bookTitle: segments[0],
      orderSegments: [segments[0]],
    );
  }
  if (segments.length == 2) {
    return build(
      author: segments[0],
      bookTitle: segments[1],
      orderSegments: [segments[1]],
    );
  }
  if (segments.length == 3) {
    final mid = segments[1];
    final book = segments[2];
    // Unnumbered container + numbered book → universe/container (e.g. Cosmere/01 - Elantris).
    // Numbered mid → saga (e.g. Author/02 - Mistborn/Book).
    final midOrder = orderTokenFromSegment(mid);
    if (midOrder == null && orderTokenFromSegment(book) != null) {
      return build(
        author: segments[0],
        universe: mid,
        bookTitle: book,
        orderSegments: [book],
      );
    }
    return build(
      author: segments[0],
      saga: mid,
      bookTitle: book,
      orderSegments: [mid, book],
    );
  }

  // 4+: Author / Universe / Saga / [Era…] / Book
  final author = segments[0];
  final universe = segments[1];
  var saga = segments[2];
  String? era;
  final bookTitle = segments.last;
  final middle = segments.sublist(2, segments.length - 1);
  if (middle.isNotEmpty) {
    saga = middle.first;
    final eras = middle.skip(1).where(looksLikeEraFolder).toList();
    if (eras.isNotEmpty) {
      era = eras.last;
    } else if (middle.length >= 2 && looksLikeEraFolder(middle[1])) {
      era = middle[1];
    } else if (middle.length >= 2 && looksLikePartFolder(middle[1])) {
      // Legacy: treat non-era part-like segment as era slot when present.
      era = middle[1];
    }
  }

  return build(
    author: author,
    universe: universe,
    saga: saga,
    era: era,
    bookTitle: bookTitle,
    orderSegments: [
      ...middle,
      bookTitle,
    ],
  );
}

String formatDuration(double seconds) {
  final h = (seconds ~/ 3600).toString().padLeft(2, '0');
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toStringAsFixed(3).padLeft(6, '0');
  return '$h:$m:$s';
}
