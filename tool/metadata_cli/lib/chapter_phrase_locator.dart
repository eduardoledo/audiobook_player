import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'cli_whisper.dart';
import 'detection_progress.dart';
import 'epub_structure.dart';
import 'proximity_windows.dart';
import 'sherpa_native.dart';
import 'structure_match.dart';

/// Silence-based candidates + Whisper ASR to locate EPUB opening phrases.
class ChapterPhraseLocator {
  /// Fast mode (default): skip full-file silence scan, coarse→fine sampling,
  /// shorter ASR windows, more threads, input-seek PCM extract.
  final bool fast;

  final double minSilenceSeconds;
  final String noiseDb;
  final double windowSeconds;
  final double minGapSeconds;
  final double fallbackIntervalSeconds;
  final int minCandidates;
  final String language;
  final int numThreads;
  final int progressEveryWindows;

  /// Coarse sampling step inside proximity (fast mode).
  final double coarseStepSeconds;

  /// After a weak hit (depth≥[refineMinDepth]), densify this radius.
  final double refineRadiusSeconds;
  final double fineStepSeconds;
  final int refineMinDepth;

  /// Depth needed to treat a hit as a real coincidence (lone common words
  /// like "ash" alone are not enough to stop searching / densify far away).
  final int coincidenceMinDepth;

  /// Keep expanding the proximity window until the first coincidence, up to this
  /// many extra seconds beyond the initial window (default 5 minutes).
  final double maxExpandToleranceSeconds;
  final double expandStepSeconds;

  ChapterPhraseLocator({
    this.fast = true,
    this.minSilenceSeconds = 1.2,
    this.noiseDb = '-30dB',
    double? windowSeconds,
    this.minGapSeconds = 15,
    this.fallbackIntervalSeconds = 480,
    this.minCandidates = 8,
    this.language = 'en',
    int? numThreads,
    this.progressEveryWindows = 3,
    this.coarseStepSeconds = 45,
    this.refineRadiusSeconds = 150,
    this.fineStepSeconds = 5,
    this.refineMinDepth = 3,
    this.coincidenceMinDepth = 3,
    this.maxExpandToleranceSeconds = 300,
    this.expandStepSeconds = 60,
  })  : windowSeconds = windowSeconds ?? (fast ? 10.0 : 12.0),
        numThreads = numThreads ??
            (fast
                ? math.min(8, math.max(2, Platform.numberOfProcessors))
                : 3);

  /// Locates each EPUB entry using opening phrases.
  ///
  /// Pass [totalBookWords] when [entries] is a prefix of the full EPUB so
  /// proximity windows stay scaled to the whole audiobook.
  ///
  /// When [knownCuts] is provided (same length as [entries]), non-null slots are
  /// kept as-is and ASR continues from the next unknown chapter, searching only
  /// until the following known start when available.
  Future<List<AlignedChapterCut?>> locate({
    required String audioPath,
    required List<EpubTocEntry> entries,
    required double durationSeconds,
    int? totalBookWords,
    List<AlignedChapterCut?>? knownCuts,
    void Function(String msg)? onLog,
    bool Function()? isCancelled,
  }) async {
    if (knownCuts != null && knownCuts.length != entries.length) {
      throw ArgumentError(
        'knownCuts length (${knownCuts.length}) must match entries '
        '(${entries.length})',
      );
    }
    final progress = DetectionProgress(onLog: onLog);
    final model = CliWhisperModelManager();
    await model.ensureModel(onStatus: progress.log);

    final knownCount = knownCuts == null
        ? 0
        : knownCuts.where((c) => c != null).length;
    if (knownCount > 0) {
      progress.log(
        'Resuming from saved timeline: $knownCount/${entries.length} known — '
        'locating the rest',
      );
    }

    List<double> silenceCandidates = const [];
    if (fast) {
      progress.log(
        'Fast mode: skipping full-file silence scan '
        '(coarse→fine inside proximity windows)',
      );
    } else {
      progress.log('Finding silence candidates (thorough)…');
      silenceCandidates = await findSilenceCandidates(
        audioPath,
        durationSeconds: durationSeconds,
        progress: progress,
      );
      progress.silenceDone(silenceCandidates.length);
    }

    final nativeDir = await resolveSherpaNativeLibDir();
    progress.log('Loading sherpa native libs from $nativeDir');
    sherpa.initBindings(nativeDir);
    final whisper = sherpa.OfflineWhisperModelConfig(
      encoder: model.encoderPath,
      decoder: model.decoderPath,
      language: language,
      task: 'transcribe',
    );
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: whisper,
          tokens: model.tokensPath,
          modelType: 'whisper',
          numThreads: numThreads,
          debug: false,
        ),
      ),
    );

    final tmpDir = await Directory.systemTemp.createTemp('metadata_cli_asr_');
    final cuts = <AlignedChapterCut?>[];
    var searchAfter = 0.0;

    final bookWords = totalBookWords ??
        entries.fold<int>(0, (a, e) => a + math.max(e.wordCount, 1));
    final proximity = List<ChapterProximityWindow>.from(
      buildProximityWindows(
        entries: entries,
        durationSeconds: durationSeconds,
        totalBookWords: bookWords,
        // Tighter windows in fast mode.
        minHalfWidthSeconds: fast ? 60 : 90,
        maxHalfWidthSeconds: fast ? 600 : 1200,
        chapterRadiusFactor: fast ? 0.35 : 0.55,
        partRadiusFactor: fast ? 0.05 : 0.08,
      ),
    );
    final subsetWords =
        entries.fold<int>(0, (a, e) => a + math.max(e.wordCount, 1));
    progress.log(
      'Proximity windows from EPUB sizes '
      '($subsetWords'
      '${bookWords != subsetWords ? "w of ${bookWords}w book" : "w"})'
      '${fast ? " [fast]" : " [thorough]"}',
    );

    try {
      for (var i = 0; i < entries.length; i++) {
        if (isCancelled?.call() == true) break;
        final entry = entries[i];
        final known = knownCuts?[i];
        if (known != null) {
          cuts.add(known);
          final drift = known.startSeconds - proximity[i].expectedStart;
          if (drift.abs() >= 5 && i + 1 < proximity.length) {
            for (var j = i + 1; j < proximity.length; j++) {
              proximity[j] = proximity[j].shiftBySeconds(
                deltaSeconds: drift,
                durationSeconds: durationSeconds,
                minStart: known.startSeconds + 20,
              );
            }
          }
          searchAfter = known.startSeconds + 20;
          progress.log(
            '  skip [saved] [${i + 1}/${entries.length}] ${entry.title} @ '
            '${DetectionProgress.fmtTime(known.startSeconds)}',
          );
          progress.chapterDone(
            index1Based: i + 1,
            total: entries.length,
            title: entry.title,
            foundAt: known.startSeconds,
            fuzzy: false,
          );
          continue;
        }

        final needle = entry.firstWordsNormalized;
        if (needle.length < 5) {
          progress.log(
            '  ! [${i + 1}/${entries.length}] ${entry.title}: phrase too short',
          );
          cuts.add(null);
          progress.chaptersDone = i + 1;
          progress.chaptersMissing++;
          continue;
        }

        // Cap search before the next already-known chapter start.
        var hardEnd = durationSeconds;
        if (knownCuts != null) {
          for (var j = i + 1; j < knownCuts.length; j++) {
            final next = knownCuts[j];
            if (next != null) {
              hardEnd = math.min(hardEnd, next.startSeconds - 5);
              break;
            }
          }
        }
        if (hardEnd <= searchAfter + 1) {
          progress.log(
            '  ! [${i + 1}/${entries.length}] ${entry.title}: '
            'no search room before next known chapter',
          );
          cuts.add(null);
          progress.chaptersDone = i + 1;
          progress.chaptersMissing++;
          continue;
        }

        // Shared openings (e.g. Mistborn prologue/ch1 both start "Ash fell
        // from the sky") need more than the common prefix to count.
        var chapterCoincidenceMin = coincidenceMinDepth;
        if (i > 0) {
          final prev = entries[i - 1].firstWordsNormalized;
          var shared = 0;
          while (shared < needle.length &&
              shared < prev.length &&
              needle[shared] == prev[shared]) {
            shared++;
          }
          if (shared >= 3) {
            chapterCoincidenceMin = math.max(
              coincidenceMinDepth,
              shared + 1,
            );
            progress.log(
              '  shared prefix $shared with previous → '
              'coincidence≥$chapterCoincidenceMin',
            );
          }
        }

        var window = proximity[i];
        window = ChapterProximityWindow(
          index: window.index,
          entry: window.entry,
          expectedStart: window.expectedStart
              .clamp(searchAfter, hardEnd)
              .toDouble(),
          expectedDuration: window.expectedDuration,
          searchStart: math.max(window.searchStart, searchAfter),
          searchEnd: math.min(window.searchEnd, hardEnd),
          wordCount: window.wordCount,
          partWordCount: window.partWordCount,
        );
        if (window.searchEnd <= window.searchStart + 1) {
          // Proximity missed the gap — search the whole remaining band.
          window = ChapterProximityWindow(
            index: window.index,
            entry: window.entry,
            expectedStart:
                (searchAfter + (hardEnd - searchAfter) * 0.5).clamp(
              searchAfter,
              hardEnd,
            ),
            expectedDuration: hardEnd - searchAfter,
            searchStart: searchAfter,
            searchEnd: hardEnd,
            wordCount: window.wordCount,
            partWordCount: window.partWordCount,
          );
        }

        progress.log(
          '  proximity [${i + 1}] ${entry.title}: '
          'expect ${DetectionProgress.fmtTime(window.expectedStart)} '
          '(~${window.expectedDuration.toStringAsFixed(0)}s, '
          '${window.wordCount}w / part ${window.partWordCount}w) '
          'search ${DetectionProgress.fmtTime(window.searchStart)}'
          '→${DetectionProgress.fmtTime(window.searchEnd)}',
        );

        var result = await _searchProgressive(
          audioPath: audioPath,
          recognizer: recognizer,
          tmpDir: tmpDir,
          silenceCandidates: silenceCandidates,
          window: window,
          minStart: searchAfter,
          needle: needle,
          targetWords: needle.length,
          progress: progress,
          chapterIndex1Based: i + 1,
          chaptersTotal: entries.length,
          title: entry.title,
          refineAtDepth: chapterCoincidenceMin,
        );

        // Weak hits (e.g. lone "ash") are noise — force a fine pass over the
        // whole proximity window before expanding outward.
        if (result == null || result.depth < chapterCoincidenceMin) {
          progress.log(
            '  fine pass over proximity '
            '(best ${result?.depth ?? 0}/${needle.length})',
          );
          final finePass = await _searchProgressive(
            audioPath: audioPath,
            recognizer: recognizer,
            tmpDir: tmpDir,
            silenceCandidates: silenceCandidates,
            window: window,
            minStart: searchAfter,
            needle: needle,
            targetWords: needle.length,
            progress: progress,
            chapterIndex1Based: i + 1,
            chaptersTotal: entries.length,
            title: entry.title,
            priorBest: result,
            forceFineGrid: true,
            refineAtDepth: chapterCoincidenceMin,
          );
          if (finePass != null &&
              (result == null || finePass.depth > result.depth)) {
            result = finePass;
          }
        }

        // Expand by steps until a real coincidence, max +5 minutes.
        var expandedBy = 0.0;
        var current = window;
        while ((result == null || result.depth < chapterCoincidenceMin) &&
            expandedBy < maxExpandToleranceSeconds) {
          final step = math.min(
            expandStepSeconds,
            maxExpandToleranceSeconds - expandedBy,
          );
          if (step <= 0) break;
          expandedBy += step;
          final next = current.expandBySeconds(
            seconds: step,
            durationSeconds: hardEnd,
            minStart: searchAfter,
          );
          if (next.searchStart >= current.searchStart - 0.01 &&
              next.searchEnd <= current.searchEnd + 0.01) {
            break; // hit audio bounds
          }
          progress.log(
            '  expanding +${step.toStringAsFixed(0)}s '
            '(${expandedBy.toStringAsFixed(0)}/${maxExpandToleranceSeconds.toStringAsFixed(0)}s tol) → '
            '${DetectionProgress.fmtTime(next.searchStart)}'
            '→${DetectionProgress.fmtTime(next.searchEnd)}',
          );
          final retry = await _searchProgressive(
            audioPath: audioPath,
            recognizer: recognizer,
            tmpDir: tmpDir,
            silenceCandidates: silenceCandidates,
            window: next,
            minStart: searchAfter,
            needle: needle,
            targetWords: needle.length,
            progress: progress,
            chapterIndex1Based: i + 1,
            chaptersTotal: entries.length,
            title: entry.title,
            priorBest: result,
            // Only sample the newly added outer bands.
            excludeInner: current,
            refineAtDepth: chapterCoincidenceMin,
          );
          if (retry != null &&
              (result == null || retry.depth > result.depth)) {
            result = retry;
          }
          current = next;
          if (result != null && result.depth >= chapterCoincidenceMin) {
            progress.log(
              '  first coincidence depth ${result.depth} @ '
              '${DetectionProgress.fmtTime(result.atSeconds)}',
            );
            // If not full phrase yet, one densified pass around the hit.
            if (result.depth < needle.length) {
              final refineWin = ChapterProximityWindow(
                index: current.index,
                entry: current.entry,
                expectedStart: result.atSeconds,
                expectedDuration: current.expectedDuration,
                searchStart: math.max(
                  searchAfter,
                  result.atSeconds - refineRadiusSeconds,
                ),
                searchEnd: math.min(
                  hardEnd,
                  result.atSeconds + refineRadiusSeconds,
                ),
                wordCount: current.wordCount,
                partWordCount: current.partWordCount,
              );
              final refined = await _searchProgressive(
                audioPath: audioPath,
                recognizer: recognizer,
                tmpDir: tmpDir,
                silenceCandidates: silenceCandidates,
                window: refineWin,
                minStart: searchAfter,
                needle: needle,
                targetWords: needle.length,
                progress: progress,
                chapterIndex1Based: i + 1,
                chaptersTotal: entries.length,
                title: entry.title,
                priorBest: result,
                forceFineGrid: true,
                stepOverride: 2,
                refineAtDepth: chapterCoincidenceMin,
              );
              if (refined != null && refined.depth >= result.depth) {
                result = refined;
              }
            }
            break;
          }
        }

        // If we had a coincidence but not the full phrase, widen looking for
        // a fuller match (still re-scan near the hit, not only outer bands).
        if (result != null &&
            result.depth >= chapterCoincidenceMin &&
            result.depth < needle.length) {
          var widen = current;
          var used = expandedBy;
          while (result!.depth < needle.length &&
              used < maxExpandToleranceSeconds) {
            final step = math.min(
              expandStepSeconds,
              maxExpandToleranceSeconds - used,
            );
            if (step <= 0) break;
            used += step;
            final next = widen.expandBySeconds(
              seconds: step,
              durationSeconds: hardEnd,
              minStart: searchAfter,
            );
            progress.log(
              '  widening for fuller phrase +${step.toStringAsFixed(0)}s '
              '(${used.toStringAsFixed(0)}/${maxExpandToleranceSeconds.toStringAsFixed(0)}s) '
              'best ${result.depth}/${needle.length}',
            );
            // Dense pass around the best hit inside the widened window.
            final aroundHit = ChapterProximityWindow(
              index: next.index,
              entry: next.entry,
              expectedStart: result.atSeconds,
              expectedDuration: next.expectedDuration,
              searchStart: math.max(
                searchAfter,
                result.atSeconds - refineRadiusSeconds,
              ),
              searchEnd: math.min(
                hardEnd,
                result.atSeconds + refineRadiusSeconds,
              ),
              wordCount: next.wordCount,
              partWordCount: next.partWordCount,
            );
            final retry = await _searchProgressive(
              audioPath: audioPath,
              recognizer: recognizer,
              tmpDir: tmpDir,
              silenceCandidates: silenceCandidates,
              window: aroundHit,
              minStart: searchAfter,
              needle: needle,
              targetWords: needle.length,
              progress: progress,
              chapterIndex1Based: i + 1,
              chaptersTotal: entries.length,
              title: entry.title,
              priorBest: result,
              forceFineGrid: true,
              stepOverride: 2,
              refineAtDepth: chapterCoincidenceMin,
            );
            if (retry != null && retry.depth > result.depth) {
              result = retry;
            }
            widen = next;
            if (result.depth >= needle.length) break;
          }
        }

        // Nudge earlier a few seconds once we have a strong phrase hit so the
        // cut lands near the spoken opening, not mid-sentence.
        if (result != null && result.depth >= chapterCoincidenceMin) {
          result = await _backtrackOnset(
                audioPath: audioPath,
                recognizer: recognizer,
                tmpDir: tmpDir,
                hit: result,
                minStart: searchAfter,
                needle: needle,
                progress: progress,
              ) ??
              result;
        }

        double? accepted;
        var soft = false;
        if (result != null) {
          if (result.depth >= needle.length) {
            accepted = result.atSeconds;
          } else if (result.depth >= needle.length - 1) {
            accepted = result.atSeconds;
            soft = true;
          }
        }

        progress.chapterDone(
          index1Based: i + 1,
          total: entries.length,
          title: entry.title,
          foundAt: accepted,
          fuzzy: soft,
        );
        if (result != null && accepted != null) {
          progress.log(
            '  progressive match ${result.depth}/${needle.length} words'
            '${soft ? " (soft)" : ""}',
          );
        }

        if (accepted == null) {
          cuts.add(null);
          continue;
        }
        cuts.add(
          AlignedChapterCut(
            epub: entry,
            startSeconds: accepted,
            endSeconds: durationSeconds,
          ),
        );
        // Drift later proximity windows when this chapter landed off its
        // word-share estimate (common after dedications / music intros).
        final drift = accepted - window.expectedStart;
        if (drift.abs() >= 5 && i + 1 < proximity.length) {
          progress.log(
            '  drift ${drift >= 0 ? "+" : ""}'
            '${drift.toStringAsFixed(0)}s → shifting later windows',
          );
          for (var j = i + 1; j < proximity.length; j++) {
            proximity[j] = proximity[j].shiftBySeconds(
              deltaSeconds: drift,
              durationSeconds: durationSeconds,
              minStart: accepted + 20,
            );
          }
        }
        searchAfter = accepted + 20;
      }
    } finally {
      recognizer.free();
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    }

    progress.summary();

    final resolved = <AlignedChapterCut?>[];
    for (var i = 0; i < cuts.length; i++) {
      final c = cuts[i];
      if (c == null) {
        resolved.add(null);
        continue;
      }
      double end = durationSeconds;
      for (var j = i + 1; j < cuts.length; j++) {
        final n = cuts[j];
        if (n != null) {
          end = n.startSeconds;
          break;
        }
      }
      resolved.add(
        AlignedChapterCut(
          epub: c.epub,
          startSeconds: c.startSeconds,
          endSeconds: end,
        ),
      );
    }
    return resolved;
  }

  /// Locate [missing] inside the audio file that already holds [previous].
  ///
  /// Treats the file as spanning only those two chapters (by word count) so the
  /// search window stays inside this file instead of the whole book.
  Future<AlignedChapterCut?> locateInPreviousFile({
    required String audioPath,
    required EpubTocEntry previous,
    required EpubTocEntry missing,
    required double durationSeconds,
    void Function(String msg)? onLog,
  }) async {
    final wPrev = math.max(previous.wordCount, 1);
    final wMiss = math.max(missing.wordCount, 1);
    onLog?.call(
      'Bounded locate «${missing.title}» inside ${p.basename(audioPath)} '
      '(expect ~${DetectionProgress.fmtTime(durationSeconds * wPrev / (wPrev + wMiss))} '
      'of ${DetectionProgress.fmtTime(durationSeconds)})',
    );
    final located = await locate(
      audioPath: audioPath,
      entries: [previous, missing],
      durationSeconds: durationSeconds,
      totalBookWords: wPrev + wMiss,
      onLog: onLog,
    );
    if (located.length < 2) return null;
    return located[1];
  }

  Future<_ProgressiveHit?> _searchProgressive({
    required String audioPath,
    required sherpa.OfflineRecognizer recognizer,
    required Directory tmpDir,
    required List<double> silenceCandidates,
    required ChapterProximityWindow window,
    required double minStart,
    required List<String> needle,
    required int targetWords,
    required DetectionProgress progress,
    required int chapterIndex1Based,
    required int chaptersTotal,
    required String title,
    _ProgressiveHit? priorBest,
    ChapterProximityWindow? excludeInner,
    bool forceFineGrid = false,
    double? stepOverride,
    int? refineAtDepth,
  }) async {
    final densifyAt = refineAtDepth ?? refineMinDepth;
    final step = stepOverride ?? (forceFineGrid ? fineStepSeconds : null);
    List<double> rawTimes;
    if (forceFineGrid || stepOverride != null) {
      rawTimes = sampleProximityTimes(
        window: window,
        minStart: minStart,
        stepSeconds: step ?? fineStepSeconds,
      );
    } else if (fast) {
      rawTimes = _coarseToFineSchedule(window: window, minStart: minStart);
    } else {
      rawTimes = candidatesInProximity(
        silenceCandidates: silenceCandidates,
        window: window,
        minStart: minStart,
        densifyStepSeconds: 25,
      );
    }

    // When expanding, only evaluate the newly added outer bands.
    if (excludeInner != null) {
      final lo = excludeInner.searchStart;
      final hi = excludeInner.searchEnd;
      rawTimes = rawTimes
          .where((t) => t < lo - 0.25 || t > hi + 0.25)
          .toList();
    }

    final times = List<double>.from(rawTimes);
    if (times.isEmpty) return priorBest;

    progress.chapterStart(
      index1Based: chapterIndex1Based,
      total: chaptersTotal,
      title: title,
      windowsTotal: times.length,
    );

    _ProgressiveHit? best = priorBest;
    // Do not raise the bar on weak prefix hits (depth 1 "ash") — those are
    // common and would skip real mid-depth matches if requiredDepth ratchets.
    var requiredDepth = 1;
    final visited = <int>{};

    for (var wi = 0; wi < times.length; wi++) {
      final t = times[wi];
      final key = (t * 100).round();
      if (!visited.add(key)) continue;

      if (wi % progressEveryWindows == 0 || wi == times.length - 1) {
        progress.chapterWindow(
          index1Based: chapterIndex1Based,
          total: chaptersTotal,
          title: title,
          windowIndex1Based: wi + 1,
          windowsTotal: times.length,
          atSeconds: t,
          extra: best == null
              ? 'need≥$requiredDepth'
              : 'best ${best.depth}/$targetWords',
        );
      }

      final pcm = await extractPcmWindow(
        audioPath: audioPath,
        startSeconds: t,
        durationSeconds: windowSeconds,
        outPath: p.join(tmpDir.path, 'win.pcm'),
        fastSeek: fast,
      );
      if (pcm == null) continue;
      final text = _transcribe(recognizer, pcm);
      if (text == null || text.trim().isEmpty) continue;

      final depth = progressiveWordMatchCount(text, needle);
      if (depth < requiredDepth) continue;

      if (best == null || depth > best.depth) {
        best = _ProgressiveHit(atSeconds: t, depth: depth, transcript: text);
        if (depth >= densifyAt) {
          requiredDepth = math.min(targetWords, depth + 1);
        }
        progress.log(
          '  depth $depth/$targetWords @ ${DetectionProgress.fmtTime(t)} '
          '«${needle.take(depth).join(' ')}»',
        );

        if (fast && depth >= densifyAt && !forceFineGrid && stepOverride == null) {
          final fine = sampleProximityTimes(
            window: ChapterProximityWindow(
              index: window.index,
              entry: window.entry,
              expectedStart: t,
              expectedDuration: window.expectedDuration,
              searchStart: math.max(minStart, t - refineRadiusSeconds),
              searchEnd: math.min(
                window.searchEnd,
                t + refineRadiusSeconds,
              ),
              wordCount: window.wordCount,
              partWordCount: window.partWordCount,
            ),
            minStart: minStart,
            stepSeconds: math.min(fineStepSeconds, 2),
          );
          for (final ft in fine) {
            final fk = (ft * 100).round();
            if (visited.contains(fk)) continue;
            times.add(ft);
          }
        }
      } else if (depth == best.depth &&
          (t - window.expectedStart).abs() <
              (best.atSeconds - window.expectedStart).abs()) {
        best = _ProgressiveHit(atSeconds: t, depth: depth, transcript: text);
      }

      if (depth >= targetWords) {
        progress.log(
          '  full phrase @ ${DetectionProgress.fmtTime(t)}: "$text"',
        );
        return best;
      }
    }
    return best;
  }

  /// Coarse grid nearest-to-expected first, plus a fine mid ring around expected.
  List<double> _coarseToFineSchedule({
    required ChapterProximityWindow window,
    required double minStart,
  }) {
    final coarse = sampleProximityTimes(
      window: window,
      minStart: minStart,
      stepSeconds: coarseStepSeconds,
    );
    // Fine-enough ring around expected so short openings (~10s) are not skipped.
    final mid = sampleProximityTimes(
      window: ChapterProximityWindow(
        index: window.index,
        entry: window.entry,
        expectedStart: window.expectedStart,
        expectedDuration: window.expectedDuration,
        searchStart: math.max(
          minStart,
          window.expectedStart - refineRadiusSeconds,
        ),
        searchEnd: math.min(
          window.searchEnd,
          window.expectedStart + refineRadiusSeconds,
        ),
        wordCount: window.wordCount,
        partWordCount: window.partWordCount,
      ),
      minStart: minStart,
      stepSeconds: fineStepSeconds,
    );
    final seen = <int>{};
    final out = <double>[];
    for (final t in [...coarse, ...mid]) {
      final k = (t * 100).round();
      if (seen.add(k)) out.add(t);
    }
    return out;
  }

  /// Probe a few seconds earlier than [hit] to land nearer the spoken onset.
  Future<_ProgressiveHit?> _backtrackOnset({
    required String audioPath,
    required sherpa.OfflineRecognizer recognizer,
    required Directory tmpDir,
    required _ProgressiveHit hit,
    required double minStart,
    required List<String> needle,
    required DetectionProgress progress,
  }) async {
    var best = hit;
    for (final delta in const [-8.0, -6.0, -4.0, -2.0, 2.0, 4.0]) {
      final t = hit.atSeconds + delta;
      if (t < minStart) continue;
      final pcm = await extractPcmWindow(
        audioPath: audioPath,
        startSeconds: t,
        durationSeconds: windowSeconds,
        outPath: p.join(tmpDir.path, 'back.pcm'),
        fastSeek: false, // accurate for final placement
      );
      if (pcm == null) continue;
      final text = _transcribe(recognizer, pcm);
      if (text == null || text.trim().isEmpty) continue;
      final depth = progressiveWordMatchCount(text, needle);
      if (depth > best.depth ||
          (depth == best.depth &&
              depth >= coincidenceMinDepth &&
              t < best.atSeconds)) {
        best = _ProgressiveHit(atSeconds: t, depth: depth, transcript: text);
      }
    }
    if (best.atSeconds != hit.atSeconds || best.depth != hit.depth) {
      progress.log(
        '  onset adjust ${_fmtDelta(hit.atSeconds, best.atSeconds)} → '
        '${DetectionProgress.fmtTime(best.atSeconds)} '
        '(${best.depth}/${needle.length})',
      );
    }
    return best;
  }

  static String _fmtDelta(double from, double to) {
    final d = to - from;
    final sign = d >= 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(0)}s';
  }

  String? _transcribe(sherpa.OfflineRecognizer recognizer, File pcmFile) {
    final bytes = pcmFile.readAsBytesSync();
    if (bytes.length < 16000) return null;
    final samples = _pcm16ToFloat32(bytes);
    final stream = recognizer.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;
    stream.free();
    return text;
  }

  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  Future<List<double>> findSilenceCandidates(
    String audioPath, {
    required double durationSeconds,
    DetectionProgress? progress,
  }) async {
    final ffmpeg = await _which('ffmpeg');
    if (ffmpeg == null) throw StateError('ffmpeg not found on PATH');

    final proc = await Process.start(
      ffmpeg,
      [
        '-hide_banner',
        '-nostats',
        '-progress',
        'pipe:2',
        '-i',
        audioPath,
        '-af',
        'silencedetect=noise=$noiseDb:d=$minSilenceSeconds',
        '-f',
        'null',
        '-',
      ],
      runInShell: false,
    );

    final errBuf = StringBuffer();
    var lastStatus = DateTime.fromMillisecondsSinceEpoch(0);
    await for (final chunk in proc.stderr.transform(
      const SystemEncoding().decoder,
    )) {
      errBuf.write(chunk);
      final now = DateTime.now();
      if (progress != null &&
          now.difference(lastStatus) > const Duration(milliseconds: 400)) {
        lastStatus = now;
        final t = _latestOutTimeSeconds(errBuf.toString());
        if (t != null) {
          progress.silenceProgress(t, durationSeconds);
        }
      }
    }
    await proc.exitCode;

    final logs = errBuf.toString();
    final silenceEnds = <double>[];
    for (final m in RegExp(r'silence_end:\s*([\d.]+)').allMatches(logs)) {
      final t = double.tryParse(m.group(1)!);
      if (t != null && t < durationSeconds) silenceEnds.add(t);
    }
    for (final m in RegExp(r'silence_start:\s*([\d.]+)').allMatches(logs)) {
      final t = double.tryParse(m.group(1)!);
      if (t != null && t > 0.5 && t < durationSeconds) {
        silenceEnds.add(t + minSilenceSeconds);
      }
    }

    final candidates = <double>{0.0};
    for (final t in silenceEnds) {
      if (t >= 0 && t < durationSeconds - 0.5) candidates.add(t);
    }
    if (candidates.length < minCandidates && durationSeconds > 0) {
      for (var t = fallbackIntervalSeconds;
          t < durationSeconds - 1;
          t += fallbackIntervalSeconds) {
        candidates.add(t);
      }
    }

    final sorted = candidates.toList()..sort();
    final thinned = <double>[];
    for (final t in sorted) {
      if (thinned.isEmpty || t - thinned.last >= minGapSeconds) {
        thinned.add(t);
      }
    }
    return thinned;
  }
}

double? _latestOutTimeSeconds(String progressLog) {
  final ms = RegExp(r'out_time_ms=(\d+)').allMatches(progressLog).lastOrNull;
  if (ms != null) {
    final v = int.tryParse(ms.group(1)!);
    if (v != null) return v / 1e6;
  }
  final t = RegExp(r'out_time=(\d+):(\d+):(\d+(?:\.\d+)?)')
      .allMatches(progressLog)
      .lastOrNull;
  if (t != null) {
    final h = int.tryParse(t.group(1)!) ?? 0;
    final m = int.tryParse(t.group(2)!) ?? 0;
    final s = double.tryParse(t.group(3)!) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  return null;
}

Future<File?> extractPcmWindow({
  required String audioPath,
  required double startSeconds,
  required double durationSeconds,
  required String outPath,
  bool fastSeek = true,
}) async {
  final ffmpeg = await _which('ffmpeg');
  if (ffmpeg == null) return null;
  // Fast: -ss before -i (keyframe seek). Accurate: -i then -ss/-t.
  final args = <String>[
    '-hide_banner',
    '-y',
    if (fastSeek) ...[
      '-ss',
      startSeconds.toStringAsFixed(3),
      '-t',
      durationSeconds.toStringAsFixed(3),
      '-i',
      audioPath,
    ] else ...[
      '-i',
      audioPath,
      '-ss',
      startSeconds.toStringAsFixed(3),
      '-t',
      durationSeconds.toStringAsFixed(3),
    ],
    '-ac',
    '1',
    '-ar',
    '16000',
    '-f',
    's16le',
    outPath,
  ];
  final result = await Process.run(ffmpeg, args);
  if (result.exitCode != 0) return null;
  final f = File(outPath);
  if (!await f.exists() || await f.length() < 100) return null;
  return f;
}

Future<double> probeDurationSeconds(String audioPath) async {
  final ffprobe = await _which('ffprobe');
  if (ffprobe == null) throw StateError('ffprobe not found');
  final r = await Process.run(ffprobe, [
    '-v',
    'quiet',
    '-show_entries',
    'format=duration',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    audioPath,
  ]);
  if (r.exitCode != 0) return 0;
  return double.tryParse((r.stdout as String).trim()) ?? 0;
}

Future<String?> _which(String name) async {
  final r = await Process.run('which', [name]);
  if (r.exitCode != 0) return null;
  final path = (r.stdout as String).trim();
  return path.isEmpty ? null : path;
}

class _ProgressiveHit {
  final double atSeconds;
  final int depth;
  final String transcript;

  const _ProgressiveHit({
    required this.atSeconds,
    required this.depth,
    required this.transcript,
  });
}
