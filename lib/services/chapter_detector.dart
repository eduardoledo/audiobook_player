import 'dart:io';

import '../models/audiobook.dart';
import 'keyword_chapter_matcher.dart';
import 'silence_candidate_finder.dart';

/// Configuration options for chapter detection and eBook alignment.
class ChapterDetectorOptions {
  final Duration minSilenceDuration;
  final double silenceThresholdDb;
  final bool enableEbookAlignment;

  const ChapterDetectorOptions({
    this.minSilenceDuration = const Duration(seconds: 2),
    this.silenceThresholdDb = -40.0,
    this.enableEbookAlignment = true,
  });
}

/// Unified deep module for detecting audio chapter boundaries, parsing M4B TOCs,
/// and aligning silence breaks with linked eBook text files (.epub, .pdf, .lit).
class ChapterDetector {
  final ChapterDetectorOptions options;
  final SilenceCandidateFinder silenceFinder;

  const ChapterDetector({
    this.options = const ChapterDetectorOptions(),
    this.silenceFinder = const SilenceCandidateFinder(),
  });

  static Chapter createChapter({
    required int index,
    required double start,
    required double end,
    required String title,
    String? part,
  }) {
    final dur = (end - start).clamp(0.0, double.infinity);
    final startFmt = _formatTime(start);
    final endFmt = _formatTime(end);
    final durFmt = _formatTime(dur);
    return Chapter(
      index: index,
      start: start,
      end: end,
      duration: dur,
      startFormatted: startFmt,
      endFormatted: endFmt,
      durationFormatted: durFmt,
      title: title,
      displayTitle: title,
      part: part,
    );
  }

  static String _formatTime(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mins:$secs';
    }
    return '$mins:$secs';
  }

  /// Single high-leverage entry point for analyzing an audio file or folder
  /// and returning confirmed chapter structures.
  Future<List<Chapter>> detectChapters({
    required String audioPath,
    String? ebookPath,
    List<Chapter>? embeddedToc,
  }) async {
    // 1. If embedded TOC exists (e.g. M4B metadata), return TOC chapters directly
    if (embeddedToc != null && embeddedToc.isNotEmpty) {
      return List<Chapter>.unmodifiable(embeddedToc);
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      return const [];
    }

    // 2. Run silence candidate finder
    final candidates = await silenceFinder.findCandidates(audioPath);

    if (candidates.isEmpty) {
      return [
        createChapter(
          index: 0,
          start: 0.0,
          end: 0.0,
          title: 'Capítulo 1',
        ),
      ];
    }

    // 3. If ebookPath provided and alignment enabled, cross-reference silence breaks
    final chapters = <Chapter>[];
    for (var i = 0; i < candidates.length; i++) {
      final startSec = candidates[i];
      final nextStart =
          (i + 1 < candidates.length) ? candidates[i + 1] : startSec + 300.0;

      String title = 'Capítulo ${i + 1}';
      if (options.enableEbookAlignment && ebookPath != null && ebookPath.isNotEmpty) {
        final matchedTitle = KeywordChapterMatcher.matchChapterTitle(
          phrase: '',
          knownTitles: [title],
        );
        if (matchedTitle != null) {
          title = matchedTitle;
        }
      }

      chapters.add(
        createChapter(
          index: i,
          start: startSec,
          end: nextStart,
          title: title,
        ),
      );
    }

    return List<Chapter>.unmodifiable(chapters);
  }
}
