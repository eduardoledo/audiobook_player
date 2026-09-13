import 'dart:io';

import 'package:path/path.dart' as p;

import 'audio_split.dart';
import 'book_metadata.dart';
import 'chapter_phrase_locator.dart';
import 'chapters_from_files.dart';
import 'epub_structure.dart';
import 'models.dart';
import 'path_metadata.dart';
import 'saved_structure.dart';
import 'structure_match.dart';

class MissingChapterGap {
  final EpubTocEntry missing;
  final EpubTocEntry previous;
  final String previousAudioPath;

  const MissingChapterGap({
    required this.missing,
    required this.previous,
    required this.previousAudioPath,
  });
}

class FillMissingResult {
  final List<EpubTocEntry> missingBefore;
  final List<EpubTocEntry> filled;
  final List<EpubTocEntry> stillMissing;
  final List<String> audioFiles;

  const FillMissingResult({
    required this.missingBefore,
    required this.filled,
    required this.stillMissing,
    required this.audioFiles,
  });
}

/// EPUB entries with no matching chapter audio file in the book root.
List<MissingChapterGap> planMissingChapterGaps({
  required EpubStructure epub,
  required List<String> audioFiles,
  required String bookPath,
}) {
  final present = <int>{};
  final fileByEpubIndex = <int, String>{};

  for (final path in audioFiles) {
    final parsed = chapterNameFromAudioPath(path, bookPath: bookPath);
    final idx = _matchEpubIndex(epub.entries, parsed.title);
    if (idx == null) continue;
    present.add(idx);
    fileByEpubIndex[idx] = path;
  }

  final gaps = <MissingChapterGap>[];
  for (var i = 0; i < epub.entries.length; i++) {
    if (present.contains(i)) continue;
    // Nearest earlier present chapter owns the audio that still contains this
    // missing opening (locate skipped it, so the cut absorbed it).
    var prev = i - 1;
    while (prev >= 0 && !present.contains(prev)) {
      prev--;
    }
    if (prev < 0) continue;
    final prevPath = fileByEpubIndex[prev];
    if (prevPath == null) continue;
    gaps.add(
      MissingChapterGap(
        missing: epub.entries[i],
        previous: epub.entries[prev],
        previousAudioPath: prevPath,
      ),
    );
  }
  return gaps;
}

int? _matchEpubIndex(List<EpubTocEntry> entries, String fileTitle) {
  for (var i = 0; i < entries.length; i++) {
    if (chapterTitlesAlign(entries[i], fileTitle)) return i;
  }
  return null;
}

/// For an already-split book, locate missing EPUB chapters inside the previous
/// chapter file and re-split that file when found.
Future<FillMissingResult> fillMissingChapters({
  required String bookPath,
  required EpubStructure epub,
  String originalsDirName = 'originals',
  bool dryRun = false,
  bool fast = true,
  void Function(String msg)? onLog,
}) async {
  void log(String m) => (onLog ?? stdout.writeln)(m);

  var files = listBookRootAudioFiles(
    bookPath,
    originalsDirName: originalsDirName,
  );
  if (files.length < 2) {
    throw StateError('Book does not look split (need ≥2 chapter audio files)');
  }

  // Fail fast if the EPUB itself would produce colliding filenames.
  ensureUniqueChapterBasenames([
    for (final e in epub.entries)
      AlignedChapterCut(epub: e, startSeconds: 0, endSeconds: 1),
  ]);

  final initialGaps = planMissingChapterGaps(
    epub: epub,
    audioFiles: files,
    bookPath: bookPath,
  );
  if (initialGaps.isEmpty) {
    log('No missing chapters relative to EPUB (${epub.entries.length} entries, '
        '${files.length} files)');
    return FillMissingResult(
      missingBefore: const [],
      filled: const [],
      stillMissing: const [],
      audioFiles: files,
    );
  }

  log(
    'Missing ${initialGaps.length} chapter(s) vs EPUB — '
    'searching inside previous chapter file(s)',
  );
  for (final g in initialGaps) {
    log(
      '  · ${g.missing.title} ← look in ${p.basename(g.previousAudioPath)} '
      '(after ${g.previous.title})',
    );
  }

  final locator = ChapterPhraseLocator(fast: fast);
  final filled = <EpubTocEntry>[];
  final stillMissing = <EpubTocEntry>[];

  // Process in EPUB order; refresh file list after each successful split.
  for (final planned in initialGaps) {
    files = listBookRootAudioFiles(
      bookPath,
      originalsDirName: originalsDirName,
    );
    final gaps = planMissingChapterGaps(
      epub: epub,
      audioFiles: files,
      bookPath: bookPath,
    );
    final gap = gaps.where((g) => _sameEntry(g.missing, planned.missing)).firstOrNull;
    if (gap == null) {
      log('  ✓ ${planned.missing.title} already present — skip');
      continue;
    }

    final duration = await probeDurationSeconds(gap.previousAudioPath);
    if (duration <= 0) {
      log('  ! ${gap.missing.title}: cannot probe ${gap.previousAudioPath}');
      stillMissing.add(gap.missing);
      continue;
    }

    final hit = await locator.locateInPreviousFile(
      audioPath: gap.previousAudioPath,
      previous: gap.previous,
      missing: gap.missing,
      durationSeconds: duration,
      onLog: log,
    );
    if (hit == null || hit.startSeconds < 1 || hit.startSeconds > duration - 1) {
      log(
        '  ✗ ${gap.missing.title}: not found in '
        '${p.basename(gap.previousAudioPath)}',
      );
      stillMissing.add(gap.missing);
      continue;
    }

    log(
      '  ✓ ${gap.missing.title} @ '
      '${formatDuration(hit.startSeconds)} in '
      '${p.basename(gap.previousAudioPath)}',
    );

    final ext = p.extension(gap.previousAudioPath);
    final prevCut = AlignedChapterCut(
      epub: gap.previous,
      startSeconds: 0,
      endSeconds: hit.startSeconds,
    );
    final prevOut = p.join(bookPath, '${chapterOutputBasename(prevCut)}$ext');
    final missOut = p.join(bookPath, '${chapterOutputBasename(hit)}$ext');
    if (p.normalize(prevOut) == p.normalize(missOut)) {
      log(
        '  ✗ ${gap.missing.title}: output name collides with '
        '${gap.previous.title} ("${chapterOutputBasename(hit)}")',
      );
      stillMissing.add(gap.missing);
      continue;
    }
    final missKey = p.basenameWithoutExtension(missOut).toLowerCase();
    final collision = files.any((f) {
      if (p.normalize(f) == p.normalize(gap.previousAudioPath)) return false;
      return p.basenameWithoutExtension(f).toLowerCase() == missKey;
    });
    if (collision) {
      log(
        '  ✗ ${gap.missing.title}: file already exists '
        '("${p.basename(missOut)}")',
      );
      stillMissing.add(gap.missing);
      continue;
    }

    if (dryRun) {
      log('  Dry-run: would split → ${p.basename(prevOut)} + ${p.basename(missOut)}');
      filled.add(gap.missing);
      continue;
    }

    await splitOneFileAtCut(
      sourcePath: gap.previousAudioPath,
      cutSeconds: hit.startSeconds,
      previousOutPath: prevOut,
      missingOutPath: missOut,
      onLog: log,
    );
    filled.add(gap.missing);
  }

  files = listBookRootAudioFiles(
    bookPath,
    originalsDirName: originalsDirName,
  );
  if (!dryRun && filled.isNotEmpty) {
    await _rewriteMetadataFromFiles(
      bookPath: bookPath,
      audioFiles: _orderFilesByEpub(
        epub: epub,
        audioFiles: files,
        bookPath: bookPath,
      ),
      onLog: log,
    );
  }

  final remaining = planMissingChapterGaps(
    epub: epub,
    audioFiles: files,
    bookPath: bookPath,
  ).map((g) => g.missing).toList();

  return FillMissingResult(
    missingBefore: initialGaps.map((g) => g.missing).toList(),
    filled: filled,
    stillMissing: remaining.isNotEmpty ? remaining : stillMissing,
    audioFiles: files,
  );
}

bool _sameEntry(EpubTocEntry a, EpubTocEntry b) {
  if (identical(a, b)) return true;
  if (a.chapterNumber != null && a.chapterNumber == b.chapterNumber) {
    return true;
  }
  return chapterTitlesAlign(a, b.title);
}

/// Sort chapter files by EPUB TOC order (filenames no longer carry an index).
List<String> _orderFilesByEpub({
  required EpubStructure epub,
  required List<String> audioFiles,
  required String bookPath,
}) {
  final ordered = <String>[];
  final used = <String>{};
  for (final entry in epub.entries) {
    for (final f in audioFiles) {
      if (used.contains(f)) continue;
      final parsed = chapterNameFromAudioPath(f, bookPath: bookPath);
      if (chapterTitlesAlign(entry, parsed.title)) {
        ordered.add(f);
        used.add(f);
        break;
      }
    }
  }
  for (final f in audioFiles) {
    if (!used.contains(f)) ordered.add(f);
  }
  return ordered;
}

Future<void> _rewriteMetadataFromFiles({
  required String bookPath,
  required List<String> audioFiles,
  void Function(String msg)? onLog,
}) async {
  final chapters = await detectChaptersFromFileNames(
    audioFiles: audioFiles,
    bookPath: bookPath,
  );
  final relation = relateChaptersToParts(
    chapters: chapters,
    audioFiles: audioFiles,
    bookPath: bookPath,
  );
  final existing = loadBookMetadata(bookPath);
  final meta = existing ??
      BookMetadata(
        title: p.basename(bookPath),
        author: 'Unknown',
      );
  meta.chapters = relation.chapters;
  meta.parts = relation.parts;
  final total = relation.chapters.fold<double>(0, (a, c) {
    return a + ((c['duration'] as num?)?.toDouble() ?? 0);
  });
  if (total > 0) meta.durationFormatted = formatDuration(total);
  await saveBookMetadata(bookPath, meta);
  onLog?.call(
    'Wrote book.metadata.json (${relation.chapters.length} chapters'
    '${relation.parts.isEmpty ? "" : ", ${relation.parts.length} parts"})',
  );
}
