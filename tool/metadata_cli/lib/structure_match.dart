import 'embedded_chapters.dart';
import 'epub_structure.dart';

/// Result of aligning embedded audio chapters with EPUB TOC.
class StructureMatchResult {
  /// True when embedded cuts can be used with EPUB titles/parts.
  final bool matched;

  /// Fraction of EPUB entries that aligned by title/number (0–1).
  final double titleAlignRatio;

  /// When [matched], one cut per EPUB content entry (EPUB title/part + embedded times).
  final List<AlignedChapterCut> cuts;

  final String reason;

  const StructureMatchResult({
    required this.matched,
    required this.titleAlignRatio,
    required this.cuts,
    required this.reason,
  });
}

/// A chapter boundary to apply (timestamps from audio, labels from EPUB).
class AlignedChapterCut {
  final EpubTocEntry epub;
  final double startSeconds;
  final double endSeconds;

  const AlignedChapterCut({
    required this.epub,
    required this.startSeconds,
    required this.endSeconds,
  });
}

/// Cross-checks embedded chapters against EPUB structure.
///
/// EPUB labels always win. Embedded timestamps are used only when counts match
/// and ≥80% of titles/numbers align.
StructureMatchResult matchEmbeddedToEpub({
  required EpubStructure epub,
  required List<EmbeddedChapter> embedded,
  double minAlignRatio = 0.8,
}) {
  final entries = epub.contentEntries;
  if (entries.isEmpty) {
    return const StructureMatchResult(
      matched: false,
      titleAlignRatio: 0,
      cuts: [],
      reason: 'EPUB has no content entries',
    );
  }
  if (embedded.isEmpty) {
    return const StructureMatchResult(
      matched: false,
      titleAlignRatio: 0,
      cuts: [],
      reason: 'Audio has no embedded chapters',
    );
  }
  if (embedded.length != entries.length) {
    return StructureMatchResult(
      matched: false,
      titleAlignRatio: 0,
      cuts: const [],
      reason:
          'Count mismatch: EPUB ${entries.length} vs embedded ${embedded.length}',
    );
  }

  var aligned = 0;
  for (var i = 0; i < entries.length; i++) {
    if (_titlesAlign(entries[i], embedded[i].title)) aligned++;
  }
  final ratio = aligned / entries.length;
  if (ratio < minAlignRatio) {
    return StructureMatchResult(
      matched: false,
      titleAlignRatio: ratio,
      cuts: const [],
      reason:
          'Title align ${(ratio * 100).toStringAsFixed(0)}% < ${(minAlignRatio * 100).toStringAsFixed(0)}%',
    );
  }

  final cuts = <AlignedChapterCut>[];
  for (var i = 0; i < entries.length; i++) {
    cuts.add(
      AlignedChapterCut(
        epub: entries[i],
        startSeconds: embedded[i].startSeconds,
        endSeconds: embedded[i].endSeconds,
      ),
    );
  }
  return StructureMatchResult(
    matched: true,
    titleAlignRatio: ratio,
    cuts: cuts,
    reason: 'Embedded chapters align with EPUB (${(ratio * 100).toStringAsFixed(0)}%)',
  );
}

bool chapterTitlesAlign(EpubTocEntry epub, String otherTitle) {
  return _titlesAlign(epub, otherTitle);
}

bool _titlesAlign(EpubTocEntry epub, String embeddedTitle) {
  final a = _normTitle(epub.title);
  final b = _normTitle(embeddedTitle);
  if (a == b) return true;

  switch (epub.kind) {
    case EpubEntryKind.prologue:
      return RegExp(r'\b(prologue|prologo)\b').hasMatch(b) || b == '0';
    case EpubEntryKind.epilogue:
      return RegExp(r'\b(epilogue|epilogo)\b').hasMatch(b);
    case EpubEntryKind.chapter:
      final n = epub.chapterNumber;
      if (n == null) return a.contains(b) || b.contains(a);
      final embNum = _numberFromTitle(embeddedTitle);
      return embNum == n;
    case EpubEntryKind.other:
      return a.contains(b) || b.contains(a);
  }
}

String _normTitle(String s) {
  var t = s.toLowerCase().trim();
  t = t.replaceAll(RegExp(r'[^\w\s]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

int? _numberFromTitle(String title) {
  final m = RegExp(
    r'(?:chapter|cap[ií]tulo|ch\.?)?\s*0*(\d{1,3})\b',
    caseSensitive: false,
  ).firstMatch(title.trim());
  if (m != null) return int.tryParse(m.group(1)!);
  return int.tryParse(title.trim());
}
