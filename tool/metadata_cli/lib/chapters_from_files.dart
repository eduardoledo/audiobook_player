import 'package:path/path.dart' as p;

import 'duration_estimate.dart';
import 'models.dart';
import 'path_metadata.dart';

/// Title inferred from an audio filename (without extension).
class ChapterNameFromFile {
  final String title;
  final String? part;

  /// Absolute directory of the part when detected from a folder name.
  final String? partPath;
  final int? number;

  const ChapterNameFromFile({
    required this.title,
    this.part,
    this.partPath,
    this.number,
  });
}

/// Separators allowed between index / part / title segments.
/// Includes `|` (e.g. `CD1|01|Intro`).
const _sep = r'[-.:_)\]|\s]';

final _partKeywords =
    r'parte|part|disco|disc|disk|cd|libro|eras|era|acto|act|volume|vol|tomo';

/// Front/back-matter keywords treated like prologue/epilogue parts.
final _frontBackMatter =
    r'pr[oó]logo|prologue|ep[ií]logo|epilogue|intro(?:duction)?|proem|preface|foreword';

bool _subtitleLooksLikeChapterTitle(String subtitle) {
  final s = subtitle.trim();
  if (s.isEmpty) return false;
  if (RegExp(
    '^(?:chapter|cap[ií]tulo|cap\\.?|ch\\.?|$_frontBackMatter)\\b',
    caseSensitive: false,
  ).hasMatch(s)) {
    return true;
  }
  // Legacy "01 - Title" / "01|Title" after a part prefix.
  return RegExp(r'^\d{1,4}\s*[-–—:|_.]\s*\S').hasMatch(s);
}

/// Cleans a basename into a human chapter title.
///
/// Examples:
/// - `01 - The Storm` → `The Storm`
/// - `01|The Storm` → `The Storm`
/// - `Chapter 02 - Arrival` → `Arrival`
/// - `Capítulo 3` → `Capítulo 3`
/// - `01` → `Capítulo 1`
String cleanChapterFileName(String basename) {
  var s = basename.trim();
  if (s.isEmpty) return s;

  // "Chapter 01 - Title" / "Capítulo 1|Title" / "Ch02 Title"
  final chapPrefix = RegExp(
    '^(?:chapter|cap[ií]tulo|cap\\.?|ch\\.?|track|pista)\\s*'
    '[\\._|-]?\\s*'
    '(\\d{1,4}|[ivxlcdm]+)\\s*'
    '(?:$_sep+(.*))?\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (chapPrefix != null) {
    final n = chapPrefix.group(1)!;
    final rest = (chapPrefix.group(2) ?? '').trim();
    if (rest.isNotEmpty) return _stripRedundantChapterPrefix(rest);
    final asInt = int.tryParse(n) ?? _romanToIntLoose(n);
    return asInt != null ? 'Capítulo $asInt' : 'Capítulo $n';
  }

  // "01 - Title" / "001. Title" / "01_Title" / "01|Title"
  final numbered = RegExp(
    '^(\\d{1,4})\\s*$_sep+(.+)\$',
  ).firstMatch(s);
  if (numbered != null) {
    final rest = numbered.group(2)!.trim();
    return _stripRedundantChapterPrefix(rest);
  }

  // Bare track index
  final bare = RegExp(r'^(\d{1,4})$').firstMatch(s);
  if (bare != null) {
    return 'Capítulo ${int.parse(bare.group(1)!)}';
  }

  return s;
}

String _stripRedundantChapterPrefix(String title) {
  final m = RegExp(
    '^(?:chapter|cap[ií]tulo|cap\\.?|ch\\.?)\\s*'
    '[\\._|-]?\\s*'
    '(?:\\d{1,4}|[ivxlcdm]+)\\s*'
    '(?:$_sep+(.*))?\$',
    caseSensitive: false,
  ).firstMatch(title.trim());
  if (m == null) return title.trim();
  final rest = (m.group(1) ?? '').trim();
  return rest.isNotEmpty ? rest : title.trim();
}

/// Extracts a part label embedded in a filename or directory basename, if any.
///
/// Examples:
/// - `CD1|01 - Intro` → (`CD1`, `01 - Intro`)
/// - `1| Part I - Chapter 01` → (`Part I`, `Chapter 01`)
/// - `1| Part I - Come Together - Chapter 12` → (`Part I - Come Together`, `Chapter 12`)
/// - `01 - Part I - Come Together` → (`Part I - Come Together`, ``)
/// - `5| Epilogue - Chapter 53` → (`Epilogue`, `Chapter 53`)
/// - `Part I - 1` → (`Part I`, `Chapter 1`)
/// - `Part II` → (`Part II`, ``)
({String part, String rest})? extractPartFromFileName(String basename) {
  var s = basename.trim();
  if (s.isEmpty) return null;

  // Strip leading track/part index when followed by Part/Epilogue/Prologue:
  // "1| Part I …", "01 - Part II …", "05 - Epilogue", "E| Epilogue …", "0| Intro"
  final lead = RegExp(
    r'^[A-Za-z0-9]{1,4}\s*[|._\-–—:)\s]+\s*'
    '(?=(?:part|parte|$_frontBackMatter)\\b)',
    caseSensitive: false,
  ).firstMatch(s);
  if (lead != null) {
    s = s.substring(lead.end).trim();
  }

  // Split off chapter/track remainder: "… - Chapter 12"
  String? chapterRest;
  final chapSplit = RegExp(
    r'\s*[-–—:|]\s*(?=(?:chapter|cap[ií]tulo|cap\.?|ch\.?|track|pista)\b)',
    caseSensitive: false,
  ).firstMatch(s);
  if (chapSplit != null) {
    chapterRest = s.substring(chapSplit.end).trim();
    s = s.substring(0, chapSplit.start).trim();
  }

  // Literary parts: "Part I", "Part II - The Mayfair Witches", "Part I - 1"
  final literary = RegExp(
    r'^(part|parte)\s+([ivxlcdm]+|\d+)\b(?:\s*[-–—:|]\s*(.+))?$',
    caseSensitive: false,
  ).firstMatch(s);
  if (literary != null) {
    final romanOrNum = literary.group(2)!;
    final subtitle = literary.group(3)?.trim();
    final isRoman =
        RegExp(r'^[ivxlcdm]+$', caseSensitive: false).hasMatch(romanOrNum);
    final label = isRoman
        ? 'Part ${romanOrNum.toUpperCase()}'
        : 'Part $romanOrNum';

    // "Part I - 1" / "Part III - 2" → part label + chapter index
    if (subtitle != null && RegExp(r'^\d{1,4}$').hasMatch(subtitle)) {
      final chapter = chapterRest?.isNotEmpty == true
          ? chapterRest!
          : 'Chapter $subtitle';
      return (part: label, rest: chapter);
    }

    // "Part 1 - Prologue" / "Part 1 - Chapter 3" / "Part 1 - 01 - Title"
    // → keep part label clean and use subtitle as the chapter title.
    if (subtitle != null &&
        subtitle.isNotEmpty &&
        (chapterRest == null || chapterRest.isEmpty) &&
        _subtitleLooksLikeChapterTitle(subtitle)) {
      return (part: label, rest: subtitle);
    }

    final part =
        (subtitle != null && subtitle.isNotEmpty) ? '$label - $subtitle' : label;
    return (part: part, rest: chapterRest ?? '');
  }

  // Prologue / epilogue / intro / proem (optional trailing subtitle)
  final pe = RegExp(
    '^($_frontBackMatter)\\b(?:\\s*[-–—:|]\\s*(.+))?\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (pe != null) {
    final base = _formatPartLabel(keyword: pe.group(1), value: null)!;
    final subtitle = pe.group(2)?.trim();
    if (chapterRest != null && chapterRest.isNotEmpty) {
      // "Epilogue - Interview … - Chapter 1" → part keeps subtitle
      final part = (subtitle != null && subtitle.isNotEmpty)
          ? '$base - $subtitle'
          : base;
      return (part: part, rest: chapterRest);
    }
    if (subtitle != null && subtitle.isNotEmpty) {
      // "Prólogo|Opening" / "Epilogue - Credits" → chapter title is subtitle
      return (part: base, rest: subtitle);
    }
    return (part: base, rest: '');
  }

  // Restore chapterRest into s for legacy CD/Disc parsers when no literary part.
  if (chapterRest != null && chapterRest.isNotEmpty) {
    s = '$s - $chapterRest';
  }

  // Keyword + number/label, then separator + rest (CD1, Disc 2, …).
  final withRest = RegExp(
    '^(?:'
    '($_partKeywords)(?:'
    '[\\s._|-]*(\\d{1,4}|[ivxlcdm]+)'
    '|[\\s._|-]+([A-Za-z][A-Za-z0-9_-]*)'
    ')'
    '|'
    '($_frontBackMatter)(?:[\\s._|-]*(\\d{1,4}))?'
    ')'
    '\\s*$_sep+\\s*(.+)\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (withRest != null) {
    final part = _formatPartLabel(
      keyword: withRest.group(1) ?? withRest.group(4),
      value: withRest.group(2) ?? withRest.group(3) ?? withRest.group(5),
    );
    final rest = withRest.group(6)!.trim();
    if (part != null && rest.isNotEmpty) {
      return (part: part, rest: rest);
    }
  }

  // Entire basename is a part label (useful for directory names).
  final onlyPart = RegExp(
    '^(?:'
    '($_partKeywords)(?:'
    '[\\s._|-]*(\\d{1,4}|[ivxlcdm]+)'
    '|[\\s._|-]+([A-Za-z][A-Za-z0-9_-]*)'
    ')'
    '|'
    '($_frontBackMatter)(?:[\\s._|-]*(\\d{1,4}))?'
    ')\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (onlyPart != null) {
    final part = _formatPartLabel(
      keyword: onlyPart.group(1) ?? onlyPart.group(4),
      value: onlyPart.group(2) ?? onlyPart.group(3) ?? onlyPart.group(5),
    );
    if (part != null) return (part: part, rest: '');
  }
  if (looksLikePartFolder(s)) {
    return (part: s, rest: '');
  }

  return null;
}

String? _formatPartLabel({String? keyword, String? value}) {
  if (keyword == null) return null;
  final k = keyword.trim();
  if (k.isEmpty) return null;
  final v = value?.trim();
  if (v == null || v.isEmpty) {
    // Preserve original casing for prologue/epilogue/front matter when possible
    if (RegExp(r'^pr[oó]logo$', caseSensitive: false).hasMatch(k)) {
      return 'Prólogo';
    }
    if (RegExp(r'^prologue$', caseSensitive: false).hasMatch(k)) {
      return 'Prologue';
    }
    if (RegExp(r'^ep[ií]logo$', caseSensitive: false).hasMatch(k)) {
      return 'Epílogo';
    }
    if (RegExp(r'^epilogue$', caseSensitive: false).hasMatch(k)) {
      return 'Epilogue';
    }
    if (RegExp(r'^intro(?:duction)?$', caseSensitive: false).hasMatch(k)) {
      return 'Intro';
    }
    if (RegExp(r'^proem$', caseSensitive: false).hasMatch(k)) {
      return 'Proem';
    }
    if (RegExp(r'^preface$', caseSensitive: false).hasMatch(k)) {
      return 'Preface';
    }
    if (RegExp(r'^foreword$', caseSensitive: false).hasMatch(k)) {
      return 'Foreword';
    }
    return k;
  }

  // Normalize common keywords for display
  final lower = k.toLowerCase();
  final pretty = switch (lower) {
    'cd' => 'CD',
    'disc' || 'disk' || 'disco' => 'Disc',
    'part' || 'parte' => 'Parte',
    'vol' || 'volume' || 'tomo' => 'Vol',
    'era' || 'eras' => 'Era',
    'acto' || 'act' => 'Acto',
    'libro' => 'Libro',
    _ => k,
  };

  final asInt = int.tryParse(v) ?? _romanToIntLoose(v);
  if (asInt != null && RegExp(r'^\d+$').hasMatch(v)) {
    if (pretty == 'CD') return 'CD$asInt';
    return '$pretty $asInt';
  }
  if (asInt != null &&
      RegExp(r'^[ivxlcdm]+$', caseSensitive: false).hasMatch(v)) {
    return '$pretty $asInt';
  }
  return '$pretty $v';
}

int? _romanToIntLoose(String roman) {
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

/// Parses chapter label + optional part (directory and/or filename) under [bookPath].
ChapterNameFromFile chapterNameFromAudioPath(
  String audioPath, {
  required String bookPath,
}) {
  final base = p.basenameWithoutExtension(audioPath);
  final fromDir = extractPartFromDirectoryPath(
    audioPath,
    bookPath: bookPath,
  );

  String? part = fromDir?.part;
  String? partPath = fromDir?.path;

  var working = base;
  final fromName = extractPartFromFileName(base);
  if (part == null && fromName != null) {
    part = fromName.part;
    if (fromName.rest.isNotEmpty) {
      working = fromName.rest;
    } else {
      // Bare part/front-matter file (`Part II.mp3`, `Epilogue.mp3`) →
      // one chapter inside that part.
      working = 'Chapter 1';
    }
  } else if (part != null) {
    // Directory already owns the part: strip a redundant part prefix from the
    // filename so titles stay clean (`Parte 9|01 - Intro` → `Intro`).
    if (fromName != null && fromName.rest.isNotEmpty) {
      working = fromName.rest;
    } else {
      final stripped = RegExp(
        r'^(?:'
        r'(?:part|parte)\s+(?:[ivxlcdm]+|\d+)'
        r'|(?:cd|disc|disk|disco)[\s._|-]*\d+'
        r')\s*[|._\-–—:]\s*',
        caseSensitive: false,
      ).firstMatch(base);
      if (stripped != null) {
        working = base.substring(stripped.end).trim();
      }
    }
  }

  final title = cleanChapterFileName(working);
  final numMatch = RegExp(r'(\d{1,4})').firstMatch(working);
  final number = numMatch != null ? int.tryParse(numMatch.group(1)!) : null;

  return ChapterNameFromFile(
    title: title.isEmpty ? working : title,
    part: part,
    partPath: partPath,
    number: number,
  );
}

/// Finds a part label in any directory between [bookPath] and the audio file.
///
/// Prefers the deepest matching folder (closest to the file). Also accepts
/// directory names that embed a part prefix (`CD1|tracks`, `Parte 2 - audio`).
({String part, String path})? extractPartFromDirectoryPath(
  String audioPath, {
  required String bookPath,
}) {
  final normalizedBook = p.normalize(bookPath);
  final fileDir = p.normalize(p.dirname(audioPath));

  if (fileDir == normalizedBook) return null;
  if (!p.isWithin(normalizedBook, fileDir) &&
      !fileDir.startsWith('$normalizedBook${p.separator}')) {
    return null;
  }

  final relative = p.relative(fileDir, from: normalizedBook);
  final segments =
      p.split(relative).where((s) => s.isNotEmpty && s != '.').toList();
  if (segments.isEmpty) return null;

  // Deepest first: Book/CD1/extra/file → prefer CD1 over nothing in "extra".
  for (var i = segments.length - 1; i >= 0; i--) {
    final seg = segments[i];
    final dirPath = p.normalize(
      p.joinAll([normalizedBook, ...segments.sublist(0, i + 1)]),
    );

    // Prefer embedded labels ("CD1|audio", "Parte 2 - tracks") over the
    // raw folder name when the segment only *starts* like a part.
    final embedded = extractPartFromFileName(seg);
    if (embedded != null) {
      return (part: embedded.part, path: dirPath);
    }
    if (looksLikePartFolder(seg)) {
      return (part: seg, path: dirPath);
    }
  }
  return null;
}

/// Builds chapter maps (same schema as the app [Chapter.toJson]) from filenames.
///
/// This is the first detection strategy; durations are optional estimates.
/// Part labels come from parent folders and/or the filename itself.
Future<List<Map<String, dynamic>>> detectChaptersFromFileNames({
  required List<String> audioFiles,
  required String bookPath,
  bool includeDurations = true,
  List<double>? durationsSeconds,
}) async {
  if (audioFiles.isEmpty) return const [];

  List<double> durations;
  if (durationsSeconds != null &&
      durationsSeconds.length == audioFiles.length) {
    durations = durationsSeconds;
  } else if (includeDurations) {
    durations = await estimateDurationSecondsList(audioFiles);
  } else {
    durations = List<double>.filled(audioFiles.length, 0);
  }

  final chapters = <Map<String, dynamic>>[];
  var cursor = 0.0;
  for (var i = 0; i < audioFiles.length; i++) {
    final parsed = chapterNameFromAudioPath(
      audioFiles[i],
      bookPath: bookPath,
    );
    final dur = durations[i] < 0 ? 0.0 : durations[i];
    final start = cursor;
    final end = cursor + dur;
    cursor = end;

    final display = parsed.title;

    chapters.add({
      'index': i + 1,
      'start': start,
      'end': end,
      'duration': dur,
      'startFormatted': formatDuration(start),
      'endFormatted': formatDuration(end),
      'durationFormatted': formatDuration(dur),
      'title': parsed.title,
      // Never embed the part name in the chapter title / displayTitle.
      'displayTitle': display,
      if (parsed.part != null) 'part': parsed.part,
    });
  }
  return chapters;
}

/// True for prologue/epilogue/intro-style labels (with optional numbering/prefix).
bool isPrologueOrEpilogueLabel(String name) {
  final n = name.trim();
  if (n.isEmpty) return false;
  return RegExp(
    '(?:^|.*\\b)(?:$_frontBackMatter)\\b',
    caseSensitive: false,
  ).hasMatch(n);
}

/// Removes a leading part label from a chapter title, if present.
String stripPartNameFromTitle(String title, String? part) {
  var t = title.trim();
  if (t.isEmpty || part == null || part.trim().isEmpty) return t;
  final partTrim = part.trim();
  if (t.toLowerCase() == partTrim.toLowerCase()) {
    // Whole-file parts (`Part IV - Title.mp3`) → keep a chapter label.
    return 'Chapter 1';
  }
  final escaped = RegExp.escape(partTrim);
  t = t.replaceFirst(
    RegExp('^$escaped\\s*[-–—:|•]\\s*', caseSensitive: false),
    '',
  );
  t = t.trim();
  if (t.isEmpty) return 'Chapter 1';
  return t;
}

/// Finalizes chapter maps for persistence:
/// - strips part name from [title]/[displayTitle]
/// - if [exposeParts] is false (only prologue/epilogue, or no parts), drops `part`
List<Map<String, dynamic>> finalizeChapterTitles(
  List<Map<String, dynamic>> chapters, {
  required bool exposeParts,
}) {
  return chapters.map((c) {
    final out = Map<String, dynamic>.from(c);
    final part = out['part']?.toString().trim();
    var title = out['title']?.toString() ?? '';
    var display = out['displayTitle']?.toString() ?? title;
    if (part != null && part.isNotEmpty) {
      title = stripPartNameFromTitle(title, part);
      display = stripPartNameFromTitle(display, part);
    }
    final cleaned = title.isNotEmpty ? title : display;
    out['title'] = cleaned;
    out['displayTitle'] = cleaned;
    if (!exposeParts) {
      out.remove('part');
    }
    return out;
  }).toList();
}

/// Builds [BookPart] entries from chapters / audio paths that carry a part label.
///
/// Parts may come from directory names and/or filenames.
/// If the only detected labels are prologue/epilogue, returns empty so they are
/// grouped with regular chapters instead of shown as parts.
List<BookPart> bookPartsFromChapters({
  required List<Map<String, dynamic>> chapters,
  required List<String> audioFiles,
  required String bookPath,
}) {
  if (audioFiles.isEmpty) return const [];

  final filesByPart = <String, List<String>>{};
  final durationByPart = <String, double>{};
  final pathByPart = <String, String>{};

  for (var i = 0; i < audioFiles.length; i++) {
    final parsed = chapterNameFromAudioPath(
      audioFiles[i],
      bookPath: bookPath,
    );
    final part = parsed.part?.trim();
    if (part == null || part.isEmpty) continue;

    filesByPart.putIfAbsent(part, () => []).add(audioFiles[i]);
    final dur = i < chapters.length
        ? ((chapters[i]['duration'] as num?)?.toDouble() ?? 0)
        : 0.0;
    durationByPart[part] = (durationByPart[part] ?? 0) + dur;
    if (parsed.partPath != null &&
        parsed.partPath!.isNotEmpty &&
        !pathByPart.containsKey(part)) {
      pathByPart[part] = parsed.partPath!;
    }
  }

  final parts = <BookPart>[];
  for (final entry in filesByPart.entries) {
    final dur = durationByPart[entry.key] ?? 0;
    parts.add(
      BookPart(
        name: entry.key,
        path: pathByPart[entry.key] ?? p.join(bookPath, entry.key),
        audioFiles: entry.value,
        order: partOrderFromFolderName(entry.key),
        durationFormatted: dur > 0 ? formatDuration(dur) : null,
      ),
    );
  }
  parts.sort(BookMetadata.comparePartsByOrder);

  final hasStructural =
      parts.any((p) => !isPrologueOrEpilogueLabel(p.name));
  if (!hasStructural) {
    // Only prologue and/or epilogue → don't expose as parts.
    return const [];
  }
  return parts;
}

/// Result of linking detected chapters with [parts].
class ChaptersPartsRelation {
  final List<Map<String, dynamic>> chapters;
  final List<BookPart> parts;

  /// Chapter indices (1-based) whose `part` is missing while [parts] is non-empty.
  final List<int> chaptersMissingPart;

  /// `chapter.part` values with no matching [parts] entry.
  final List<String> orphanChapterParts;

  /// Part names that no chapter references.
  final List<String> partsWithoutChapters;

  const ChaptersPartsRelation({
    required this.chapters,
    required this.parts,
    this.chaptersMissingPart = const [],
    this.orphanChapterParts = const [],
    this.partsWithoutChapters = const [],
  });

  bool get isConsistent =>
      chaptersMissingPart.isEmpty &&
      orphanChapterParts.isEmpty &&
      partsWithoutChapters.isEmpty;
}

/// Builds parts from audio paths, finalizes chapter titles, and verifies that
/// every chapter.part matches a parts[] entry when structural parts exist.
ChaptersPartsRelation relateChaptersToParts({
  required List<Map<String, dynamic>> chapters,
  required List<String> audioFiles,
  required String bookPath,
}) {
  final parts = bookPartsFromChapters(
    chapters: chapters,
    audioFiles: audioFiles,
    bookPath: bookPath,
  );
  final finalized = finalizeChapterTitles(
    chapters,
    exposeParts: parts.isNotEmpty,
  );

  if (parts.isEmpty) {
    return ChaptersPartsRelation(chapters: finalized, parts: parts);
  }

  final partNames = parts.map((p) => p.name).toSet();
  final used = <String>{};
  final missing = <int>[];
  final orphan = <String>{};

  for (final c in finalized) {
    final part = c['part']?.toString().trim();
    final index = (c['index'] as num?)?.toInt() ?? 0;
    if (part == null || part.isEmpty) {
      if (index > 0) missing.add(index);
      continue;
    }
    if (!partNames.contains(part)) {
      orphan.add(part);
    } else {
      used.add(part);
    }
  }

  final unused =
      partNames.where((n) => !used.contains(n)).toList()..sort();

  return ChaptersPartsRelation(
    chapters: finalized,
    parts: parts,
    chaptersMissingPart: missing,
    orphanChapterParts: orphan.toList()..sort(),
    partsWithoutChapters: unused,
  );
}

/// True when existing chapters look empty / generic placeholders.
bool chaptersNeedDetection(List<dynamic> chapters) {
  if (chapters.isEmpty) return true;
  var meaningful = 0;
  for (final raw in chapters) {
    if (raw is! Map) continue;
    final title = (raw['title'] ?? raw['displayTitle'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    if (RegExp(r'^(chapter|cap[ií]tulo)\s*\d+$', caseSensitive: false)
        .hasMatch(title)) {
      continue;
    }
    meaningful++;
  }
  return meaningful == 0;
}
