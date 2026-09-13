import 'dart:math' as math;

import 'epub_structure.dart';

/// Expected audio placement of one EPUB chapter from relative text size.
class ChapterProximityWindow {
  final int index;
  final EpubTocEntry entry;

  /// Estimated start in the audiobook (seconds).
  final double expectedStart;

  /// Estimated chapter duration from word-count share (seconds).
  final double expectedDuration;

  /// Inclusive search range around [expectedStart].
  final double searchStart;
  final double searchEnd;

  /// Words in this chapter / its part (for diagnostics).
  final int wordCount;
  final int partWordCount;

  const ChapterProximityWindow({
    required this.index,
    required this.entry,
    required this.expectedStart,
    required this.expectedDuration,
    required this.searchStart,
    required this.searchEnd,
    required this.wordCount,
    required this.partWordCount,
  });

  double get searchWidth => math.max(0, searchEnd - searchStart);

  /// Grow both edges by [seconds] (clamped to audio / [minStart]).
  ChapterProximityWindow expandBySeconds({
    required double seconds,
    required double durationSeconds,
    required double minStart,
  }) {
    return ChapterProximityWindow(
      index: index,
      entry: entry,
      expectedStart: expectedStart,
      expectedDuration: expectedDuration,
      searchStart: math.max(minStart, searchStart - seconds),
      searchEnd: math.min(durationSeconds, searchEnd + seconds),
      wordCount: wordCount,
      partWordCount: partWordCount,
    );
  }

  /// Shift expected start + search band by [deltaSeconds] (e.g. after a prior
  /// chapter was found earlier/later than its word-share estimate).
  ChapterProximityWindow shiftBySeconds({
    required double deltaSeconds,
    required double durationSeconds,
    required double minStart,
  }) {
    final nextExpected =
        (expectedStart + deltaSeconds).clamp(0.0, durationSeconds).toDouble();
    return ChapterProximityWindow(
      index: index,
      entry: entry,
      expectedStart: nextExpected,
      expectedDuration: expectedDuration,
      searchStart: math.max(minStart, searchStart + deltaSeconds),
      searchEnd: math.min(durationSeconds, searchEnd + deltaSeconds),
      wordCount: wordCount,
      partWordCount: partWordCount,
    );
  }

  ChapterProximityWindow expanded({
    required double durationSeconds,
    required double minStart,
    double factor = 2.0,
  }) {
    final half = searchWidth * factor / 2;
    final center = expectedStart;
    return ChapterProximityWindow(
      index: index,
      entry: entry,
      expectedStart: expectedStart,
      expectedDuration: expectedDuration,
      searchStart: math.max(minStart, center - half),
      searchEnd: math.min(durationSeconds, center + half),
      wordCount: wordCount,
      partWordCount: partWordCount,
    );
  }
}

/// Builds proximity windows from EPUB chapter/part word counts vs audio length.
///
/// Each chapter gets a share of [durationSeconds] proportional to its
/// [EpubTocEntry.wordCount]. The search radius grows with chapter length and a
/// fraction of its part length (parts with uneven chapters get more slack).
List<ChapterProximityWindow> buildProximityWindows({
  required List<EpubTocEntry> entries,
  required double durationSeconds,

  /// Full-book narrative word count when [entries] is a prefix/subset.
  /// Without this, limiting to the first N chapters stretches them across the
  /// entire audio (e.g. chapter 1 expected at ~9h instead of ~34m).
  int? totalBookWords,
  double minHalfWidthSeconds = 90,
  double maxHalfWidthSeconds = 1200,
  double chapterRadiusFactor = 0.55,
  double partRadiusFactor = 0.08,
}) {
  if (entries.isEmpty || durationSeconds <= 0) return const [];

  final weights = entries.map((e) => math.max(e.wordCount, 1)).toList();
  final subsetWords = weights.fold<int>(0, (a, b) => a + b);
  final totalWords =
      (totalBookWords != null && totalBookWords > subsetWords)
          ? totalBookWords
          : subsetWords;

  // Part → total words (within the provided entries; used for search slack).
  final partWords = <String, int>{};
  for (var i = 0; i < entries.length; i++) {
    final key = entries[i].part ?? '_';
    partWords[key] = (partWords[key] ?? 0) + weights[i];
  }

  final out = <ChapterProximityWindow>[];
  var cursor = 0.0;
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final w = weights[i];
    final dur = durationSeconds * (w / totalWords);
    final expectedStart = cursor;
    final partKey = e.part ?? '_';
    final pWords = partWords[partKey] ?? w;
    final partDur = durationSeconds * (pWords / totalWords);

    final half = _clamp(
      dur * chapterRadiusFactor + partDur * partRadiusFactor,
      minHalfWidthSeconds,
      maxHalfWidthSeconds,
    );

    // Keep left edge from going before previous chapter's expected midpoint
    // on first pass; caller further clamps with searchAfter from real finds.
    final searchStart = math.max(0.0, expectedStart - half);
    final searchEnd = math.min(durationSeconds, expectedStart + half);

    out.add(
      ChapterProximityWindow(
        index: i,
        entry: e,
        expectedStart: expectedStart,
        expectedDuration: dur,
        searchStart: searchStart,
        searchEnd: searchEnd,
        wordCount: w,
        partWordCount: pWords,
      ),
    );
    cursor += dur;
  }
  return out;
}

/// Sample times inside [window], nearest to [window.expectedStart] first.
List<double> sampleProximityTimes({
  required ChapterProximityWindow window,
  required double minStart,
  required double stepSeconds,
}) {
  final start = math.max(window.searchStart, minStart);
  final end = window.searchEnd;
  if (end <= start) return const [];

  final set = <double>{start, end};
  if (window.expectedStart >= start && window.expectedStart <= end) {
    set.add(window.expectedStart);
  }
  final step = math.max(1.0, stepSeconds);
  for (var t = start; t <= end; t += step) {
    set.add(t);
  }

  final list = set.toList()
    ..sort((a, b) {
      final da = (a - window.expectedStart).abs();
      final db = (b - window.expectedStart).abs();
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.compareTo(b);
    });
  return list;
}

/// Candidates inside [window], sorted nearest to [window.expectedStart] first.
List<double> candidatesInProximity({
  required List<double> silenceCandidates,
  required ChapterProximityWindow window,
  required double minStart,
  double densifyStepSeconds = 25,
}) {
  final start = math.max(window.searchStart, minStart);
  final end = window.searchEnd;
  if (end <= start) return const [];

  final set = <double>{};
  for (final t in silenceCandidates) {
    if (t >= start - 0.5 && t <= end + 0.5) set.add(t);
  }
  set.addAll(
    sampleProximityTimes(
      window: window,
      minStart: minStart,
      stepSeconds: densifyStepSeconds,
    ),
  );

  final list = set.toList()
    ..sort((a, b) {
      final da = (a - window.expectedStart).abs();
      final db = (b - window.expectedStart).abs();
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.compareTo(b);
    });
  return list;
}

double _clamp(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}
