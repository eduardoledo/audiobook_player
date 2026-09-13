import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Kind of a TOC content entry (parts are tracked separately).
enum EpubEntryKind { prologue, chapter, epilogue, other }

/// One content entry from the EPUB TOC (prologue / chapter / epilogue).
class EpubTocEntry {
  final String title;
  final String href;
  final EpubEntryKind kind;
  final int? chapterNumber;

  /// Display part label when known (`Part 1`, `Part One`, …).
  final String? part;

  /// First ~10 narrative words (original casing, space-separated).
  final String firstWords;

  /// Normalized lowercase words used for exact ASR matching.
  final List<String> firstWordsNormalized;

  /// Approximate narrative word count of this chapter body (for time estimates).
  final int wordCount;

  const EpubTocEntry({
    required this.title,
    required this.href,
    required this.kind,
    this.chapterNumber,
    this.part,
    required this.firstWords,
    required this.firstWordsNormalized,
    this.wordCount = 0,
  });

  EpubTocEntry copyWith({String? part, int? wordCount}) => EpubTocEntry(
        title: title,
        href: href,
        kind: kind,
        chapterNumber: chapterNumber,
        part: part ?? this.part,
        firstWords: firstWords,
        firstWordsNormalized: firstWordsNormalized,
        wordCount: wordCount ?? this.wordCount,
      );
}

/// Parsed EPUB narrative structure.
class EpubStructure {
  final String epubPath;
  final List<EpubTocEntry> entries;

  const EpubStructure({
    required this.epubPath,
    required this.entries,
  });

  /// Content entries only (same as [entries]; parts never appear as TOC leaves here).
  List<EpubTocEntry> get contentEntries => entries;
}

/// Parses an EPUB for TOC structure, opening phrases, and part labels.
EpubStructure parseEpubStructure(String epubPath, {int phraseWordCount = 10}) {
  final file = File(epubPath);
  if (!file.existsSync()) {
    throw ArgumentError('EPUB not found: $epubPath');
  }
  final bytes = file.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final byName = <String, ArchiveFile>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    byName[_normPath(f.name)] = f;
  }

  final container = _readXml(byName, 'META-INF/container.xml');
  if (container == null) {
    throw StateError('Invalid EPUB: missing META-INF/container.xml');
  }
  final rootfile = container
      .findAllElements('rootfile', namespace: '*')
      .map((e) => e.getAttribute('full-path'))
      .whereType<String>()
      .firstOrNull;
  if (rootfile == null || rootfile.isEmpty) {
    throw StateError('Invalid EPUB: no rootfile in container.xml');
  }
  final opfPath = _normPath(rootfile);
  final opfDir = p.posix.dirname(opfPath);
  final opf = _readXml(byName, opfPath);
  if (opf == null) {
    throw StateError('Invalid EPUB: missing OPF $opfPath');
  }

  final manifest = <String, String>{};
  for (final item in opf.findAllElements('item', namespace: '*')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null) {
      manifest[id] = _resolve(opfDir, href);
    }
  }

  final spineHrefs = <String>[];
  for (final itemref in opf.findAllElements('itemref', namespace: '*')) {
    final idref = itemref.getAttribute('idref');
    if (idref == null) continue;
    final href = manifest[idref];
    if (href != null) spineHrefs.add(href);
  }

  String? ncxPath;
  String? navPath;
  for (final item in opf.findAllElements('item', namespace: '*')) {
    final props = item.getAttribute('properties') ?? '';
    final media = item.getAttribute('media-type') ?? '';
    final href = item.getAttribute('href');
    if (href == null) continue;
    final resolved = _resolve(opfDir, href);
    if (props.contains('nav') || media.contains('package+xml')) {
      if (media.contains('xhtml') || resolved.endsWith('.xhtml')) {
        navPath ??= resolved;
      }
    }
    if (media == 'application/x-dtbncx+xml') {
      ncxPath = resolved;
    }
  }
  // Fallback: any .ncx
  ncxPath ??= () {
    for (final k in byName.keys) {
      if (k.toLowerCase().endsWith('.ncx')) return k;
    }
    return null;
  }();

  final tocRaw = <({String title, String href})>[];
  if (ncxPath != null) {
    tocRaw.addAll(_parseNcx(byName, ncxPath));
  }
  if (tocRaw.isEmpty && navPath != null) {
    tocRaw.addAll(_parseNav(byName, navPath));
  }
  if (tocRaw.isEmpty) {
    throw StateError('EPUB has no NCX/nav TOC: $epubPath');
  }

  // Drop pure part-only TOC nodes (title is only "Part …" with no chapter body).
  final contentToc = tocRaw.where((e) => !_isPartOnlyTitle(e.title)).toList();

  // Part labels along spine: href → latest PART heading before that file.
  final partByHref = _partsAlongSpine(byName, spineHrefs);

  final entries = <EpubTocEntry>[];
  for (final raw in contentToc) {
    final kind = classifyEpubTitle(raw.title);
    final num = chapterNumberFromTitle(raw.title);
    final title = displayTitleFor(raw.title, kind, num);
    final hrefPath = raw.href.split('#').first;
    final html = _readText(byName, hrefPath) ?? '';
    final phrase = firstNarrativeWords(html, wordCount: phraseWordCount);
    final bodyWords = narrativeBodyWords(html);
    final part = partByHref[_normPath(hrefPath)] ??
        _nearestPart(partByHref, hrefPath, spineHrefs);
    entries.add(
      EpubTocEntry(
        title: title,
        href: hrefPath,
        kind: kind,
        chapterNumber: num,
        part: part,
        firstWords: phrase.display,
        firstWordsNormalized: phrase.normalized,
        wordCount: bodyWords.length,
      ),
    );
  }

  return EpubStructure(epubPath: epubPath, entries: entries);
}

/// Classifies a TOC label.
EpubEntryKind classifyEpubTitle(String title) {
  final t = title.trim().toLowerCase();
  if (RegExp(r'^(pr[oó]logo|prologue|preface|prefacio|introduction)$')
      .hasMatch(t)) {
    return EpubEntryKind.prologue;
  }
  if (RegExp(r'^(ep[ií]logo|epilogue|afterword|conclusion)$').hasMatch(t)) {
    return EpubEntryKind.epilogue;
  }
  if (RegExp(r'^\d+$').hasMatch(t) ||
      RegExp(r'^(chapter|cap[ií]tulo|ch\.?)\s*\d+', caseSensitive: false)
          .hasMatch(t)) {
    return EpubEntryKind.chapter;
  }
  return EpubEntryKind.other;
}

int? chapterNumberFromTitle(String title) {
  final t = title.trim();
  final bare = int.tryParse(t);
  if (bare != null) return bare;
  final m = RegExp(
    r'(?:chapter|cap[ií]tulo|ch\.?)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(t);
  if (m != null) return int.tryParse(m.group(1)!);
  return null;
}

String displayTitleFor(String raw, EpubEntryKind kind, int? number) {
  switch (kind) {
    case EpubEntryKind.prologue:
      return 'Prologue';
    case EpubEntryKind.epilogue:
      return 'Epilogue';
    case EpubEntryKind.chapter:
      return number != null ? 'Chapter $number' : raw.trim();
    case EpubEntryKind.other:
      return raw.trim();
  }
}

/// Extracts the first [wordCount] narrative words from HTML/XHTML body text.
({String display, List<String> normalized}) firstNarrativeWords(
  String html, {
  int wordCount = 10,
}) {
  final tokens = narrativeBodyWords(html);
  final kept = tokens.take(wordCount).toList();
  final display = kept.join(' ');
  final normalized =
      kept.map(normalizePhraseWord).where((w) => w.isNotEmpty).toList();
  return (display: display, normalized: normalized);
}

/// All narrative body word tokens from an HTML chapter (boilerplate stripped).
List<String> narrativeBodyWords(String html) {
  var text = html;
  text = text.replaceAll(
    RegExp(r'<(style|script)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
    ' ',
  );
  text = text.replaceAll(RegExp(r'@\w+\s*\{[^}]*\}'), ' ');
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = text.replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  text = text.replaceFirst(
    RegExp(
      r'^.{0,80}?\bBrandon Sanderson\b.{0,60}?\bThe Final Empire\b\s*',
      caseSensitive: false,
    ),
    '',
  );
  text = text.replaceFirst(
    RegExp(
      r'^[A-Z][A-Za-z .]+?\s[-–—]\s.{0,80}?\s[-–—]\s.{0,80}?(\s|$)',
    ),
    '',
  );

  final tokens = text.split(' ').where((w) => w.isNotEmpty).toList();
  var start = 0;
  while (start < tokens.length) {
    final tok = tokens[start];
    if (_isBoilerplateToken(tok) || _isStructuralHeadingToken(tok)) {
      start++;
      continue;
    }
    break;
  }
  final kept = <String>[];
  for (var i = start; i < tokens.length; i++) {
    final tok = tokens[i];
    if (_isBoilerplateToken(tok)) continue;
    kept.add(tok);
  }
  return kept;
}

String normalizePhraseWord(String word) {
  var s = word.toLowerCase();
  const map = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  map.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r"[^\w']"), '');
  return s;
}

String normalizePhrase(String text) {
  return text
      .split(RegExp(r'\s+'))
      .map(normalizePhraseWord)
      .where((w) => w.isNotEmpty)
      .join(' ');
}

bool phraseContainedExact(String transcript, List<String> needleWords) {
  return progressiveWordMatchCount(transcript, needleWords) >= needleWords.length;
}

/// Levenshtein edit distance between two short strings.
int wordEditDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (j) => j);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// ASR-tolerant word equality: exact, stem/affix containment, or small edit
/// distance on longer tokens.
bool wordsFuzzyEqual(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;

  final lo = a.length <= b.length ? a : b;
  final hi = a.length <= b.length ? b : a;
  // Whisper often expands short openings: ash→shall, vin→then (handled
  // elsewhere), or adds plural/tense: watch→watched.
  if (lo.length >= 3 && (hi.startsWith(lo) || hi.endsWith(lo))) {
    return true;
  }

  // Keep other short function words exact ("the"/"she", "a"/"i").
  if (a.length <= 3 || b.length <= 3) return false;
  final maxLen = a.length > b.length ? a.length : b.length;
  final allowed = maxLen <= 5 ? 1 : 2;
  return wordEditDistance(a, b) <= allowed;
}

/// How many leading [needleWords] match inside [transcript].
///
/// Walks the transcript looking for the longest opening-phrase prefix
/// (1 word, then 2, … up to 10). Allows up to [maxMismatches] ASR errors:
/// fuzzy token equality (e.g. trusting≈tresting), one substitution, one
/// inserted transcript word, or one skipped needle word.
int progressiveWordMatchCount(
  String transcript,
  List<String> needleWords, {
  int maxMismatches = 2,
}) {
  if (needleWords.isEmpty) return 0;
  final hay = normalizePhrase(transcript)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (hay.isEmpty) return 0;
  var best = 0;
  for (var start = 0; start < hay.length; start++) {
    var n = 0;
    var h = start;
    var errors = 0;
    while (n < needleWords.length && h < hay.length) {
      if (hay[h] == needleWords[n] || wordsFuzzyEqual(hay[h], needleWords[n])) {
        n++;
        h++;
        continue;
      }
      if (errors >= maxMismatches) break;
      // Prefer skipping an inserted ASR word if the next hay matches.
      if (h + 1 < hay.length &&
          (hay[h + 1] == needleWords[n] ||
              wordsFuzzyEqual(hay[h + 1], needleWords[n]))) {
        errors++;
        h++;
        continue;
      }
      // Skip a dropped needle word if current hay matches the next needle.
      // Allow skipping the first needle word only when the next ≥3 needle
      // tokens match (e.g. Whisper "shall fell from the sky" for "ash fell…").
      if (n + 1 < needleWords.length &&
          (hay[h] == needleWords[n + 1] ||
              wordsFuzzyEqual(hay[h], needleWords[n + 1])) &&
          (n > 0 || _lookaheadMatchRun(hay, h, needleWords, n + 1) >= 3)) {
        errors++;
        n++;
        continue;
      }
      // Substitution only when tokens are near-misses (not arbitrary words),
      // and never for the first needle word.
      if (n > 0 &&
          hay[h].length > 3 &&
          needleWords[n].length > 3 &&
          wordEditDistance(hay[h], needleWords[n]) <= 3) {
        errors++;
        n++;
        h++;
        continue;
      }
      // Short-word substitution when the *next* tokens align (e.g. vin→then
      // before watch≈watched). Without look-ahead this would reject openings
      // that Whisper tiny mangles on names.
      if (n > 0 &&
          n + 1 < needleWords.length &&
          h + 1 < hay.length &&
          (hay[h + 1] == needleWords[n + 1] ||
              wordsFuzzyEqual(hay[h + 1], needleWords[n + 1]))) {
        errors++;
        n++;
        h++;
        continue;
      }
      break;
    }
    if (n > best) best = n;
    if (best == needleWords.length) return best;
  }
  return best;
}

/// Exact/fuzzy run length of needle[needleStart…] against hay[hayStart…].
int _lookaheadMatchRun(
  List<String> hay,
  int hayStart,
  List<String> needle,
  int needleStart,
) {
  var run = 0;
  var h = hayStart;
  var n = needleStart;
  while (n < needle.length && h < hay.length) {
    if (hay[h] == needle[n] || wordsFuzzyEqual(hay[h], needle[n])) {
      run++;
      h++;
      n++;
      continue;
    }
    break;
  }
  return run;
}

bool phraseContainedFuzzy(String transcript, List<String> needleWords) {
  if (needleWords.isEmpty) return false;
  // Soft accept: fuzzy progressive match of at least N-1 words.
  return progressiveWordMatchCount(transcript, needleWords) >=
      needleWords.length - 1;
}

// --- internals ---

String _normPath(String path) => path.replaceAll('\\', '/');

String _resolve(String baseDir, String href) {
  final cleaned = href.split('#').first.replaceAll('\\', '/');
  if (baseDir == '.' || baseDir.isEmpty) return _normPath(cleaned);
  return _normPath(p.posix.normalize(p.posix.join(baseDir, cleaned)));
}

XmlDocument? _readXml(Map<String, ArchiveFile> byName, String path) {
  final text = _readText(byName, path);
  if (text == null) return null;
  try {
    return XmlDocument.parse(text);
  } catch (_) {
    return null;
  }
}

String? _readText(Map<String, ArchiveFile> byName, String path) {
  final key = _normPath(path);
  final f = byName[key] ??
      byName.entries
          .where((e) => e.key.toLowerCase() == key.toLowerCase())
          .map((e) => e.value)
          .firstOrNull;
  if (f == null) return null;
  return utf8.decode(f.content, allowMalformed: true);
}

List<({String title, String href})> _parseNcx(
  Map<String, ArchiveFile> byName,
  String ncxPath,
) {
  final doc = _readXml(byName, ncxPath);
  if (doc == null) return [];
  final ncxDir = p.posix.dirname(ncxPath);
  final out = <({String title, String href})>[];
  void walk(XmlElement el) {
    for (final child in el.childElements) {
      if (child.name.local != 'navPoint') continue;
      String title = '';
      String src = '';
      for (final c in child.childElements) {
        if (c.name.local == 'navLabel') {
          title = c.innerText.trim();
        } else if (c.name.local == 'content') {
          src = c.getAttribute('src') ?? '';
        }
      }
      if (title.isNotEmpty && src.isNotEmpty) {
        out.add((title: title, href: _resolve(ncxDir, src)));
      }
      walk(child);
    }
  }

  final navMap = doc.findAllElements('navMap', namespace: '*').firstOrNull;
  if (navMap != null) walk(navMap);
  return out;
}

List<({String title, String href})> _parseNav(
  Map<String, ArchiveFile> byName,
  String navPath,
) {
  final doc = _readXml(byName, navPath);
  if (doc == null) return [];
  final navDir = p.posix.dirname(navPath);
  final out = <({String title, String href})>[];
  for (final a in doc.findAllElements('a', namespace: '*')) {
    final href = a.getAttribute('href');
    final title = a.innerText.trim();
    if (href == null || href.isEmpty || title.isEmpty) continue;
    if (href.startsWith('#')) continue;
    out.add((title: title, href: _resolve(navDir, href)));
  }
  return out;
}

bool _isPartOnlyTitle(String title) {
  return RegExp(
    r'^(part|parte)\s+(\d+|i{1,3}|iv|v|vi{0,3}|one|two|three|four|five|primera|segunda|tercera).*$',
    caseSensitive: false,
  ).hasMatch(title.trim());
}

Map<String, String> _partsAlongSpine(
  Map<String, ArchiveFile> byName,
  List<String> spineHrefs,
) {
  final partByHref = <String, String>{};
  String? current;
  final partRe = RegExp(
    r'\bPART\s+(ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|TEN|\d+)\b'
    r'|\bPARTE\s+(PRIMERA|SEGUNDA|TERCERA|CUARTA|QUINTA|\d+)\b',
    caseSensitive: false,
  );
  for (final href in spineHrefs) {
    final html = _readText(byName, href) ?? '';
    var text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // Prefer short documents that are mainly a part title page.
    final m = partRe.firstMatch(text);
    if (m != null) {
      final token = (m.group(1) ?? m.group(2) ?? '').toUpperCase();
      current = _formatPartLabel(token);
    }
    if (current != null) {
      partByHref[_normPath(href)] = current;
    }
  }
  return partByHref;
}

String? _nearestPart(
  Map<String, String> partByHref,
  String href,
  List<String> spineHrefs,
) {
  final idx = spineHrefs.indexWhere((h) => _normPath(h) == _normPath(href));
  if (idx < 0) return partByHref[_normPath(href)];
  for (var i = idx; i >= 0; i--) {
    final p = partByHref[_normPath(spineHrefs[i])];
    if (p != null) return p;
  }
  return null;
}

String _formatPartLabel(String token) {
  const words = {
    'ONE': '1',
    'TWO': '2',
    'THREE': '3',
    'FOUR': '4',
    'FIVE': '5',
    'SIX': '6',
    'SEVEN': '7',
    'EIGHT': '8',
    'NINE': '9',
    'TEN': '10',
    'PRIMERA': '1',
    'SEGUNDA': '2',
    'TERCERA': '3',
    'CUARTA': '4',
    'QUINTA': '5',
  };
  final n = words[token.toUpperCase()] ?? token;
  return 'Part $n';
}

bool _isBoilerplateToken(String tok) {
  final t = tok.toLowerCase();
  if (t.startsWith('@')) return true;
  if (t.contains('{') || t.contains('}') || t.contains(':') && t.contains('pt')) {
    return true;
  }
  if (RegExp(r'^\d+(\.\d+)?(pt|px|em)$').hasMatch(t)) return true;
  if (t == 'margin-bottom' ||
      t == 'margin-top' ||
      t == 'margin-left' ||
      t == 'margin-right') {
    return true;
  }
  // "Brandon" "Sanderson" "-" "Mistborn" … book banner before prose
  if (t == '-' || t == '—' || t == '–') return true;
  if (RegExp(r'^\[?\d+\]?$').hasMatch(t) && t.length <= 3) {
    // handled as structural when appropriate; keep for banner skip via structural
  }
  // Skip tokens that look like CSS property leftovers
  if (t.endsWith(';') || t.endsWith('{') || t.endsWith('}')) return true;
  return false;
}

bool _isStructuralHeadingToken(String tok) {
  final t = tok.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (t.isEmpty) return true;
  if (RegExp(
        r'^(prologue|prologo|epilogue|epilogo|preface|prefacio|introduction)$',
      ).hasMatch(t)) {
    return true;
  }
  // Bare chapter index heading ("1", "38").
  if (RegExp(r'^\d{1,3}$').hasMatch(t)) return true;
  return false;
}
