import 'dart:io';

import 'package:path/path.dart' as p;

import 'audio_split.dart';
import 'book_metadata.dart';
import 'chapter_phrase_locator.dart';
import 'chapters_from_files.dart';
import 'duration_estimate.dart';
import 'embedded_chapters.dart';
import 'epub_structure.dart';
import 'missing_chapter_fill.dart';
import 'models.dart';
import 'path_metadata.dart';
import 'saved_structure.dart';
import 'structure_match.dart';

class StructurePipelineOptions {
  final String bookPath;

  /// Optional when splitting from a saved JSON timeline.
  final String? epubPath;
  final String audioPath;
  final bool dryRun;
  final bool doSplit;
  final bool yes;
  final String originalsDirName;
  final double missingAbortRatio;

  /// When true, print every EPUB/embedded/cut chapter instead of a short preview.
  final bool showAllChapters;

  /// Fast ASR locate (default). Use false for full silence scan + denser search.
  final bool fast;

  /// Ignore saved JSON timeline and re-run embedded/ASR locate.
  final bool forceLocate;

  /// When the book is already split, search missing EPUB chapters inside the
  /// previous chapter's file and re-split that file.
  final bool fillMissing;

  const StructurePipelineOptions({
    required this.bookPath,
    this.epubPath,
    required this.audioPath,
    this.dryRun = false,
    this.doSplit = false,
    this.yes = false,
    this.originalsDirName = 'originals',
    this.missingAbortRatio = 0.1,
    this.showAllChapters = false,
    this.fast = true,
    this.forceLocate = false,
    this.fillMissing = true,
  });
}

class StructurePipelineResult {
  final EpubStructure? epub;
  final StructureMatchResult? match;
  final List<AlignedChapterCut> cuts;
  final List<EpubTocEntry> missing;
  final String strategy; // 'saved' | 'embedded' | 'phrase'
  final SplitResult? split;

  const StructurePipelineResult({
    required this.epub,
    required this.match,
    required this.cuts,
    required this.missing,
    required this.strategy,
    this.split,
  });
}

/// Orchestrates EPUB → match/locate → optional split → metadata update.
///
/// When [StructurePipelineOptions.doSplit] (or `--yes` apply) and
/// `book.metadata.json` already has chapter start/end times for a still-unsplit
/// single audio file, skips EPUB/ASR locate and splits from the saved timeline.
Future<StructurePipelineResult> runStructurePipeline(
  StructurePipelineOptions opts, {
  void Function(String msg)? onLog,
}) async {
  void log(String m) => (onLog ?? stdout.writeln)(m);

  final wantsSplit = opts.doSplit || (opts.yes && !opts.dryRun);
  final alreadySplit = isBookAudioAlreadySplit(
    opts.bookPath,
    originalsDirName: opts.originalsDirName,
  );
  final existingMeta = loadBookMetadata(opts.bookPath);
  var savedCuts = opts.forceLocate ? null : cutsFromSavedMetadata(existingMeta);
  final partialSaved = opts.forceLocate
      ? null
      : cutsFromSavedMetadata(existingMeta, minChapters: 1);

  if (alreadySplit) {
    final epubPath = opts.epubPath;
    if (opts.fillMissing &&
        epubPath != null &&
        File(epubPath).existsSync()) {
      log('Book already split — checking for missing EPUB chapters');
      final epub = parseEpubStructure(epubPath);
      final fill = await fillMissingChapters(
        bookPath: opts.bookPath,
        epub: epub,
        originalsDirName: opts.originalsDirName,
        dryRun: opts.dryRun,
        fast: opts.fast,
        onLog: log,
      );
      return StructurePipelineResult(
        epub: epub,
        match: null,
        cuts: const [],
        missing: fill.stillMissing,
        strategy: 'fill-missing',
      );
    }

    if (wantsSplit && savedCuts != null) {
      log(
        'Saved chapter timeline present, but audio already looks split '
        '(${listBookRootAudioFiles(opts.bookPath, originalsDirName: opts.originalsDirName).length} '
        'files in book root). Skipping re-split. '
        'Pass --epub and --fill-missing to locate gaps inside previous files.',
      );
      return StructurePipelineResult(
        epub: null,
        match: null,
        cuts: savedCuts,
        missing: const [],
        strategy: 'saved',
      );
    }

    log(
      'Book already split '
      '(${listBookRootAudioFiles(opts.bookPath, originalsDirName: opts.originalsDirName).length} '
      'audio files). Nothing to do '
      '(use --epub with --fill-missing to hunt missing chapters).',
    );
    return StructurePipelineResult(
      epub: null,
      match: null,
      cuts: savedCuts ?? const [],
      missing: const [],
      strategy: 'saved',
    );
  }

  if (wantsSplit && savedCuts != null) {
    EpubStructure? epubForCover;
    if (opts.epubPath != null && File(opts.epubPath!).existsSync()) {
      epubForCover = parseEpubStructure(opts.epubPath!);
    }
    final alignedForSplit = epubForCover == null
        ? null
        : alignSavedCutsToEpub(saved: savedCuts, epub: epubForCover);
    final completeForSplit = alignedForSplit == null ||
        alignedCoversAll(alignedForSplit);

    if (completeForSplit) {
      ensureUniqueChapterBasenames(savedCuts);
      log(
        'Using saved chapter timeline from book.metadata.json '
        '(${savedCuts.length} chapters) — skipping locate',
      );
      EpubStructure? epub = epubForCover;
      if (epub != null) {
        log('Enriching part labels from EPUB: ${opts.epubPath}');
        savedCuts = enrichCutsWithEpubParts(cuts: savedCuts, epub: epub);
      } else {
        log('No EPUB: splitting with titles/parts from JSON only');
      }
      _logCuts(savedCuts, log, showAll: opts.showAllChapters);

      SplitResult? split;
      if (opts.dryRun) {
        log('Dry-run: skipping split and metadata write');
        split = await splitAudioByCuts(
          bookPath: opts.bookPath,
          audioPath: opts.audioPath,
          cuts: savedCuts,
          originalsDirName: opts.originalsDirName,
          dryRun: true,
          onLog: log,
        );
      } else {
        split = await splitAudioByCuts(
          bookPath: opts.bookPath,
          audioPath: opts.audioPath,
          cuts: savedCuts,
          originalsDirName: opts.originalsDirName,
          dryRun: false,
          onLog: log,
        );
        await _writeMetadataAfterSplit(
          bookPath: opts.bookPath,
          cuts: savedCuts,
          outputFiles: split.outputFiles,
          onLog: log,
        );
      }

      return StructurePipelineResult(
        epub: epub,
        match: null,
        cuts: savedCuts,
        missing: const [],
        strategy: 'saved',
        split: split,
      );
    }

    log(
      'Saved timeline incomplete vs EPUB '
      '(${countAlignedCuts(alignedForSplit)}/${epubForCover!.entries.length}) — '
      'will resume locate before split',
    );
  }

  final epubPath = opts.epubPath;
  if (epubPath == null || !File(epubPath).existsSync()) {
    throw StateError(
      'EPUB required to locate chapters. Pass --epub, or save a chapter '
      'timeline in book.metadata.json and re-run with --split.',
    );
  }

  log('Parsing EPUB: $epubPath');
  final epub = parseEpubStructure(epubPath);
  log('EPUB content entries: ${epub.entries.length}');
  _logEpubEntries(epub.entries, log, showAll: opts.showAllChapters);

  log('Reading embedded chapters: ${opts.audioPath}');
  final embedded = await readEmbeddedChapters(opts.audioPath);
  log('Embedded chapters: ${embedded.length}');
  if (opts.showAllChapters && embedded.isNotEmpty) {
    for (var i = 0; i < embedded.length; i++) {
      final c = embedded[i];
      log(
        '  emb[${i + 1}] ${c.title} '
        '${formatDuration(c.startSeconds)} → ${formatDuration(c.endSeconds)}',
      );
    }
  }
  final match = matchEmbeddedToEpub(epub: epub, embedded: embedded);
  log('Match: ${match.reason}');

  List<AlignedChapterCut> cuts;
  var strategy = 'embedded';
  final missing = <EpubTocEntry>[];

  if (match.matched) {
    cuts = List<AlignedChapterCut>.from(match.cuts);
    strategy = 'embedded';
  } else if (opts.dryRun) {
    strategy = 'phrase';
    final knownPreview = partialSaved == null
        ? null
        : alignSavedCutsToEpub(saved: partialSaved, epub: epub);
    final knownN = knownPreview == null ? 0 : countAlignedCuts(knownPreview);
    if (knownN > 0 && knownN < epub.entries.length) {
      log(
        'Dry-run: would resume locate from saved timeline '
        '($knownN/${epub.entries.length} known). '
        'Re-run without --dry-run to continue.',
      );
    } else {
      log(
        'Dry-run: skipping ASR phrase locator '
        '(${epub.entries.length} phrases ready). Re-run without --dry-run to locate.',
      );
    }
    cuts = [];
  } else {
    strategy = 'phrase';
    log('Falling back to opening-phrase ASR locator…');
    final duration = await probeDurationSeconds(opts.audioPath);
    if (duration <= 0) {
      throw StateError('Could not probe audio duration');
    }
    log('Audio duration: ${formatDuration(duration)}');
    final knownAligned = partialSaved == null
        ? null
        : alignSavedCutsToEpub(saved: partialSaved, epub: epub);
    final locator = ChapterPhraseLocator(fast: opts.fast);
    final located = await locator.locate(
      audioPath: opts.audioPath,
      entries: epub.entries,
      durationSeconds: duration,
      onLog: log,
      totalBookWords: epub.entries.fold<int>(0, (a, e) => a + e.wordCount),
      knownCuts: knownAligned,
    );
    cuts = [];
    for (var i = 0; i < located.length; i++) {
      final c = located[i];
      if (c == null) {
        missing.add(epub.entries[i]);
      } else {
        cuts.add(c);
      }
    }
    log('Located ${cuts.length}/${epub.entries.length} chapters');
  }

  final missRatio =
      epub.entries.isEmpty ? 0.0 : missing.length / epub.entries.length;
  if (cuts.isNotEmpty) {
    log('Located cuts: ${cuts.length}');
    _logCuts(cuts, log, showAll: opts.showAllChapters);
  }
  if (missing.isNotEmpty) {
    log('Missing chapters (${missing.length}):');
    final limit = opts.showAllChapters ? missing.length : 12;
    for (final m in missing.take(limit)) {
      log('  - ${m.title} «${m.firstWords}»');
    }
    if (!opts.showAllChapters && missing.length > 12) {
      log('  … +${missing.length - 12} more (use --all-chapters)');
    }
  }

  SplitResult? split;
  final shouldSplit = opts.doSplit || (opts.yes && !opts.dryRun);
  if (opts.dryRun) {
    log('Dry-run: skipping split and metadata write');
    if (cuts.isNotEmpty) {
      split = await splitAudioByCuts(
        bookPath: opts.bookPath,
        audioPath: opts.audioPath,
        cuts: cuts,
        originalsDirName: opts.originalsDirName,
        dryRun: true,
        onLog: log,
      );
    }
  } else if (shouldSplit) {
    if (missRatio > opts.missingAbortRatio) {
      throw StateError(
        'Aborting split: ${(missRatio * 100).toStringAsFixed(0)}% chapters '
        'missing (threshold ${(opts.missingAbortRatio * 100).toStringAsFixed(0)}%)',
      );
    }
    if (cuts.length < 2) {
      throw StateError('Need at least 2 located chapters to split');
    }
    split = await splitAudioByCuts(
      bookPath: opts.bookPath,
      audioPath: opts.audioPath,
      cuts: cuts,
      originalsDirName: opts.originalsDirName,
      dryRun: false,
      onLog: log,
    );
    await _writeMetadataAfterSplit(
      bookPath: opts.bookPath,
      cuts: cuts,
      outputFiles: split.outputFiles,
      onLog: log,
    );
  } else if (cuts.isNotEmpty) {
    // Update metadata timeline only (single file, no split).
    await _writeMetadataTimeline(
      bookPath: opts.bookPath,
      audioPath: opts.audioPath,
      cuts: cuts,
      onLog: log,
    );
  }

  return StructurePipelineResult(
    epub: epub,
    match: match,
    cuts: cuts,
    missing: missing,
    strategy: strategy,
    split: split,
  );
}

Future<void> _writeMetadataAfterSplit({
  required String bookPath,
  required List<AlignedChapterCut> cuts,
  required List<String> outputFiles,
  void Function(String msg)? onLog,
}) async {
  final durations = await estimateDurationSecondsList(outputFiles);
  var chapters = chaptersFromSplitFiles(
    cuts: cuts,
    outputFiles: outputFiles,
    fileDurationsSeconds: durations,
  );
  final relation = relateChaptersToParts(
    chapters: chapters,
    audioFiles: outputFiles,
    bookPath: bookPath,
  );
  chapters = relation.chapters;

  final existing = loadBookMetadata(bookPath);
  final meta = existing ??
      BookMetadata(
        title: p.basename(bookPath),
        author: 'Unknown',
      );
  meta.chapters = chapters;
  meta.parts = relation.parts;
  final total = durations.fold<double>(0, (a, b) => a + b);
  if (total > 0) meta.durationFormatted = formatDuration(total);
  await saveBookMetadata(bookPath, meta);
  onLog?.call('Wrote book.metadata.json (${chapters.length} chapters)');
}

Future<void> _writeMetadataTimeline({
  required String bookPath,
  required String audioPath,
  required List<AlignedChapterCut> cuts,
  void Function(String msg)? onLog,
}) async {
  var chapters = chaptersFromCutsTimeline(cuts);
  final relation = relateChaptersToParts(
    chapters: chapters,
    audioFiles: [audioPath],
    bookPath: bookPath,
  );
  chapters = relation.chapters;
  final existing = loadBookMetadata(bookPath);
  final meta = existing ??
      BookMetadata(
        title: p.basename(bookPath),
        author: 'Unknown',
      );
  meta.chapters = chapters;
  meta.parts = relation.parts;
  await saveBookMetadata(bookPath, meta);
  onLog?.call(
    'Wrote book.metadata.json timeline (${chapters.length} chapters, no split)',
  );
}

/// Resolves default EPUB / audio under a book directory.
({String? epub, String? audio}) discoverBookMedia(String bookPath) {
  final dir = Directory(bookPath);
  if (!dir.existsSync()) return (epub: null, audio: null);
  final epubs = <String>[];
  final audios = <String>[];
  const audioExt = {'.m4b', '.m4a', '.mp3', '.flac', '.ogg', '.opus', '.aac'};
  for (final e in dir.listSync(followLinks: false)) {
    if (e is! File) continue;
    final ext = p.extension(e.path).toLowerCase();
    if (ext == '.epub') epubs.add(e.path);
    if (audioExt.contains(ext)) audios.add(e.path);
  }
  epubs.sort();
  audios.sort();
  return (
    epub: epubs.length == 1 ? epubs.first : (epubs.isNotEmpty ? epubs.first : null),
    audio: audios.length == 1
        ? audios.first
        : (audios.isNotEmpty ? audios.first : null),
  );
}

void _logEpubEntries(
  List<EpubTocEntry> entries,
  void Function(String) log, {
  required bool showAll,
}) {
  final limit = showAll ? entries.length : 8;
  for (var i = 0; i < entries.length && i < limit; i++) {
    final e = entries[i];
    log(
      '  [${i + 1}] ${e.part != null ? "${e.part} • " : ""}${e.title} '
      '«${e.firstWords}»',
    );
  }
  if (!showAll && entries.length > 8) {
    log('  … +${entries.length - 8} more (use --all-chapters)');
  }
}

void _logCuts(
  List<AlignedChapterCut> cuts,
  void Function(String) log, {
  required bool showAll,
}) {
  final limit = showAll ? cuts.length : 8;
  for (var i = 0; i < cuts.length && i < limit; i++) {
    final c = cuts[i];
    final part = c.epub.part != null ? '${c.epub.part} • ' : '';
    log(
      '  cut[${i + 1}] $part${c.epub.title} '
      '${formatDuration(c.startSeconds)} → ${formatDuration(c.endSeconds)}',
    );
  }
  if (!showAll && cuts.length > 8) {
    log('  … +${cuts.length - 8} more (use --all-chapters)');
  }
}
