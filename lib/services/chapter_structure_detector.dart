import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/audiobook.dart';
import '../models/detected_marker.dart';
import '../models/structure_detection_models.dart';
import 'audiobook_scanner.dart';
import 'keyword_chapter_matcher.dart';
import 'silence_candidate_finder.dart';
import 'whisper_asr_worker.dart';
import 'whisper_model_manager.dart';

/// On-device structure detection: silence candidates → Whisper tiny → keywords.
class ChapterStructureDetector {
  final WhisperModelManager modelManager;
  final SilenceCandidateFinder silenceFinder;
  final KeywordChapterMatcher matcher;

  static const int sampleRate = 16000;
  static const double windowSeconds = 6.0;
  static const int asrNumThreads = 3;

  bool _cancelled = false;
  bool _paused = false;
  Completer<void>? _pauseGate;
  WhisperAsrWorker? _worker;

  double _modelProgress = 0;
  String _modelStatus = 'Preparando modelo';
  String _modelDetail = '';
  String _language = 'es';

  ChapterStructureDetector({
    WhisperModelManager? modelManager,
    SilenceCandidateFinder? silenceFinder,
    KeywordChapterMatcher? matcher,
  })  : modelManager = modelManager ?? WhisperModelManager(),
        silenceFinder = silenceFinder ?? const SilenceCandidateFinder(),
        matcher = matcher ?? KeywordChapterMatcher();

  bool get isPaused => _paused;
  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _paused = false;
    _pauseGate?.complete();
    _pauseGate = null;
  }

  void pause() {
    if (_cancelled) return;
    _paused = true;
  }

  void resume() {
    if (_cancelled) return;
    _paused = false;
    _pauseGate?.complete();
    _pauseGate = null;
  }

  bool _shouldStopWork() => _cancelled || _paused;

  void _throwIfCancelled() {
    if (_cancelled) throw StateError('cancelled');
  }

  Future<void> _waitIfPaused() async {
    while (_paused && !_cancelled) {
      _pauseGate ??= Completer<void>();
      await _pauseGate!.future;
    }
    _throwIfCancelled();
  }

  Future<void> _yieldToEventLoop() => Future<void>.delayed(Duration.zero);

  Future<void> _ensureWorker(String language) async {
    _worker ??= WhisperAsrWorker();
    if (_worker!.isReady && _worker!.language != language) {
      await _worker!.shutdown();
      _worker = WhisperAsrWorker();
    }
    await _worker!.init(
      encoderPath: await modelManager.encoderPath,
      decoderPath: await modelManager.decoderPath,
      tokensPath: await modelManager.tokensPath,
      language: language,
      numThreads: asrNumThreads,
    );
  }

  void dispose() {
    final w = _worker;
    _worker = null;
    unawaited(w?.shutdown());
  }

  StructureDetectionProgress _progress({
    required String status,
    required String detail,
    required String phaseLabel,
    required double overall,
    required double phase,
    List<DetectedMarker> markers = const [],
    bool cancellable = true,
  }) {
    return StructureDetectionProgress(
      status: _paused ? 'Pausado' : status,
      detail: _paused
          ? 'Detección en pausa. Podés aplicar resultados parciales o reanudar.'
          : detail,
      phaseLabel: phaseLabel,
      progress: overall.clamp(0.0, 1.0),
      phaseProgress: phase.clamp(0.0, 1.0),
      markers: List.unmodifiable(markers),
      paused: _paused,
      cancellable: cancellable,
    );
  }

  static String _fileLabel(String path) => p.basename(path);

  static String _formatClock(double seconds) {
    final total = seconds.round().clamp(0, 24 * 3600);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  /// Streaming detection with cooperative pause and checkpoints.
  Stream<StructureDetectionEvent> detectEvents(
    Audiobook book, {
    StructureDetectionCheckpoint? resumeFrom,
    String language = 'es',
  }) async* {
    _cancelled = false;
    _language = resumeFrom?.language ?? language;

    var rawMarkers =
        List<DetectedMarker>.from(resumeFrom?.rawMarkers ?? const []);
    List<DetectedMarker> published() => matcher.dedupe(rawMarkers);

    StructureDetectionCheckpoint makeCp({
      required List<String> files,
      required List<double> durations,
      required int fileIndex,
      required int candidateIndex,
      List<double>? candidatesForFile,
      required double timelineOffsetSec,
      bool clearCandidates = false,
    }) {
      return StructureDetectionCheckpoint(
        files: files,
        durations: durations,
        fileIndex: fileIndex,
        candidateIndex: candidateIndex,
        candidatesForFile: clearCandidates ? null : candidatesForFile,
        timelineOffsetSec: timelineOffsetSec,
        rawMarkers: List.from(rawMarkers),
        modelReady: true,
        language: _language,
      );
    }

    if (resumeFrom?.modelReady != true) {
      yield* _prepareModel(published);
    } else {
      await _ensureWorker(_language);
      await _waitIfPaused();
      _throwIfCancelled();
    }

    late final List<String> files;
    late final List<double> durations;

    if (resumeFrom != null &&
        resumeFrom.files.isNotEmpty &&
        resumeFrom.durations.length == resumeFrom.files.length) {
      files = resumeFrom.files;
      durations = resumeFrom.durations;
    } else {
      files = book.files.isNotEmpty
          ? List<String>.from(book.files)
          : await _discoverAudioFiles(book.path);
      if (files.isEmpty) {
        throw StateError('No hay archivos de audio en el libro');
      }

      yield StructureDetectionEvent(
        progress: _progress(
          status: 'Midiendo duración',
          detail: files.length == 1
              ? 'Leyendo duración de ${_fileLabel(files.first)}…'
              : 'Leyendo duración de ${files.length} archivos de audio…',
          phaseLabel: 'Preparación',
          overall: 0.21,
          phase: 0.0,
          markers: published(),
        ),
        markers: published(),
      );

      durations = <double>[];
      for (var i = 0; i < files.length; i++) {
        await _waitIfPaused();
        _throwIfCancelled();
        durations.add(await silenceFinder.getDurationSeconds(files[i]));
        yield StructureDetectionEvent(
          progress: _progress(
            status: 'Midiendo duración',
            detail:
                'Archivo ${i + 1} de ${files.length}: ${_fileLabel(files[i])} '
                '(${_formatClock(durations[i])}).',
            phaseLabel: 'Preparación',
            overall: 0.21 + ((i + 1) / files.length) * 0.04,
            phase: (i + 1) / files.length,
            markers: published(),
          ),
          markers: published(),
        );
        await _yieldToEventLoop();
      }
    }

    var totalDuration = durations.fold(0.0, (a, b) => a + b);
    if (totalDuration <= 0) totalDuration = 1;

    var fileIndex = resumeFrom?.fileIndex ?? 0;
    var timelineOffsetSec = resumeFrom?.timelineOffsetSec ?? 0.0;
    List<double>? pendingCandidates = resumeFrom?.candidatesForFile;
    var pendingCandidateIndex = resumeFrom?.candidateIndex ?? 0;

    while (fileIndex < files.length) {
      await _waitIfPaused();
      _throwIfCancelled();

      final filePath = files[fileIndex];
      final fileDur = durations[fileIndex];
      final fileWeight = fileDur / totalDuration;

      late List<double> candidates;
      var startCandidate = 0;

      if (pendingCandidates != null) {
        candidates = pendingCandidates;
        startCandidate = pendingCandidateIndex.clamp(0, candidates.length);
        pendingCandidates = null;
        pendingCandidateIndex = 0;
      } else {
        // Retry silence scan until it completes without a pause cancel.
        while (true) {
          await _waitIfPaused();
          _throwIfCancelled();

          var lastFileProgress = 0.0;
          StructureDetectionProgress silenceProgress(double fileProgress) {
            final silencePhase = (timelineOffsetSec / totalDuration) +
                fileProgress * fileWeight;
            return _progress(
              status: 'Buscando silencios',
              detail:
                  'Detectando pausas largas en ${_fileLabel(filePath)} '
                  '(archivo ${fileIndex + 1} de ${files.length}, '
                  '${_formatClock(fileProgress * fileDur)} de '
                  '${_formatClock(fileDur)}).',
              phaseLabel: 'Búsqueda de silencios',
              overall: 0.25 + silencePhase * 0.10,
              phase: silencePhase,
              markers: published(),
            );
          }

          yield StructureDetectionEvent(
            progress: silenceProgress(0.0),
            markers: published(),
            checkpoint: makeCp(
              files: files,
              durations: durations,
              fileIndex: fileIndex,
              candidateIndex: 0,
              timelineOffsetSec: timelineOffsetSec,
              clearCandidates: true,
            ),
          );

          final silenceFuture = silenceFinder.findCandidates(
            filePath,
            isCancelled: _shouldStopWork,
            onProgress: (p) => lastFileProgress = p,
          );

          var abortedByPause = false;
          Object? silenceError;
          while (true) {
            if (_cancelled) {
              try {
                await silenceFuture;
              } catch (_) {}
              throw StateError('cancelled');
            }
            if (_paused) {
              abortedByPause = true;
              try {
                await silenceFuture;
              } catch (_) {}
              break;
            }
            final done = await Future.any([
              silenceFuture.then<bool>(
                (_) => true,
                onError: (Object e, StackTrace _) {
                  silenceError = e;
                  return true;
                },
              ),
              Future<bool>.delayed(
                const Duration(milliseconds: 250),
                () => false,
              ),
            ]);
            yield StructureDetectionEvent(
              progress: silenceProgress(lastFileProgress),
              markers: published(),
              checkpoint: makeCp(
                files: files,
                durations: durations,
                fileIndex: fileIndex,
                candidateIndex: 0,
                timelineOffsetSec: timelineOffsetSec,
                clearCandidates: true,
              ),
            );
            if (done) break;
            await _yieldToEventLoop();
          }

          if (abortedByPause || _paused) {
            yield StructureDetectionEvent(
              progress: silenceProgress(lastFileProgress),
              markers: published(),
              checkpoint: makeCp(
                files: files,
                durations: durations,
                fileIndex: fileIndex,
                candidateIndex: 0,
                timelineOffsetSec: timelineOffsetSec,
                clearCandidates: true,
              ),
            );
            await _waitIfPaused();
            _throwIfCancelled();
            continue; // rescan this file
          }

          if (silenceError != null) {
            if (_cancelled ||
                silenceError.toString().contains('cancelled')) {
              _throwIfCancelled();
              // Pause race: treat as rescan
              await _waitIfPaused();
              continue;
            }
            throw silenceError!;
          }

          try {
            candidates = await silenceFuture;
          } catch (e) {
            if (_cancelled) rethrow;
            if (_paused || e.toString().contains('cancelled')) {
              await _waitIfPaused();
              _throwIfCancelled();
              continue;
            }
            rethrow;
          }
          break;
        }
      }

      final silencePhaseDone =
          (timelineOffsetSec / totalDuration) + fileWeight;
      yield StructureDetectionEvent(
        progress: _progress(
          status: 'Silencios encontrados',
          detail: candidates.isEmpty
              ? 'No se hallaron silencios claros en ${_fileLabel(filePath)}.'
              : 'Se hallaron ${candidates.length} puntos candidatos en '
                  '${_fileLabel(filePath)}.',
          phaseLabel: 'Búsqueda de silencios',
          overall: 0.25 + silencePhaseDone * 0.10,
          phase: silencePhaseDone,
          markers: published(),
        ),
        markers: published(),
        checkpoint: makeCp(
          files: files,
          durations: durations,
          fileIndex: fileIndex,
          candidateIndex: startCandidate,
          candidatesForFile: candidates,
          timelineOffsetSec: timelineOffsetSec,
        ),
      );

      for (var i = startCandidate; i < candidates.length; i++) {
        await _waitIfPaused();
        _throwIfCancelled();

        while (_paused && !_cancelled) {
          final phase = (timelineOffsetSec / totalDuration) +
              (i / candidates.length) * fileWeight;
          yield StructureDetectionEvent(
            progress: _progress(
              status: 'Pausado',
              detail:
                  'Ventana ${i + 1}/${candidates.length}. '
                  'Marcadores: ${published().length}.',
              phaseLabel: 'Reconocimiento de voz',
              overall: 0.35 + phase * 0.55,
              phase: phase,
              markers: published(),
            ),
            markers: published(),
            checkpoint: makeCp(
              files: files,
              durations: durations,
              fileIndex: fileIndex,
              candidateIndex: i,
              candidatesForFile: candidates,
              timelineOffsetSec: timelineOffsetSec,
            ),
          );
          await _waitIfPaused();
          _throwIfCancelled();
        }

        final t = candidates[i];
        final absMs = ((timelineOffsetSec + t) * 1000).round();
        final frac = candidates.isEmpty ? 1.0 : (i + 1) / candidates.length;
        final asrPhase =
            (timelineOffsetSec / totalDuration) + frac * fileWeight;
        final asrOverall = 0.35 + asrPhase * 0.55;

        yield StructureDetectionEvent(
          progress: _progress(
            status: 'Transcribiendo audio',
            detail:
                'Ventana ${i + 1} de ${candidates.length} en '
                '${_fileLabel(filePath)} '
                '(posición ${_formatClock(timelineOffsetSec + t)}). '
                'Marcadores: ${published().length}.',
            phaseLabel: 'Reconocimiento de voz',
            overall: asrOverall,
            phase: asrPhase,
            markers: published(),
          ),
          markers: published(),
          checkpoint: makeCp(
            files: files,
            durations: durations,
            fileIndex: fileIndex,
            candidateIndex: i,
            candidatesForFile: candidates,
            timelineOffsetSec: timelineOffsetSec,
          ),
        );

        final text = await _transcribeWindow(filePath, t);
        if (text != null && text.trim().isNotEmpty) {
          final marker = matcher.match(text, absMs);
          if (marker != null) rawMarkers.add(marker);
        }

        yield StructureDetectionEvent(
          progress: _progress(
            status: 'Transcribiendo audio',
            detail:
                'Ventana ${i + 1}/${candidates.length} lista. '
                'Marcadores: ${published().length}.',
            phaseLabel: 'Reconocimiento de voz',
            overall: asrOverall,
            phase: asrPhase,
            markers: published(),
          ),
          markers: published(),
          checkpoint: makeCp(
            files: files,
            durations: durations,
            fileIndex: fileIndex,
            candidateIndex: i + 1,
            candidatesForFile: candidates,
            timelineOffsetSec: timelineOffsetSec,
          ),
        );

        await _yieldToEventLoop();
      }

      timelineOffsetSec += fileDur;
      fileIndex++;
    }

    // Re-scan between jumped chapter numbers to recover missing ones.
    yield* _fillSkippedChapterGaps(
      files: files,
      durations: durations,
      rawMarkers: rawMarkers,
      published: published,
      makeCp: makeCp,
    );

    yield StructureDetectionEvent(
      progress: _progress(
        status: 'Emparejando palabras clave',
        detail: 'Candidatos crudos: ${rawMarkers.length}.',
        phaseLabel: 'Palabras clave',
        overall: 0.95,
        phase: 0.3,
        markers: published(),
      ),
      markers: published(),
    );

    final deduped = matcher.dedupe(rawMarkers);
    yield StructureDetectionEvent(
      progress: _progress(
        status: 'Listo',
        detail: deduped.isEmpty
            ? 'No se detectaron marcadores de estructura.'
            : 'Se confirman ${deduped.length} marcadores.',
        phaseLabel: 'Finalización',
        overall: 1.0,
        phase: 1.0,
        markers: deduped,
        cancellable: false,
      ),
      markers: deduped,
      done: true,
    );
  }

  /// When chapters jump (e.g. 2→5), re-transcribe windows in between for 3,4,…
  Stream<StructureDetectionEvent> _fillSkippedChapterGaps({
    required List<String> files,
    required List<double> durations,
    required List<DetectedMarker> rawMarkers,
    required List<DetectedMarker> Function() published,
    required StructureDetectionCheckpoint Function({
      required List<String> files,
      required List<double> durations,
      required int fileIndex,
      required int candidateIndex,
      List<double>? candidatesForFile,
      required double timelineOffsetSec,
      bool clearCandidates,
    }) makeCp,
  }) async* {
    const maxRounds = 2;
    const samplesPerMissing = 3;

    for (var round = 0; round < maxRounds; round++) {
      final gaps = KeywordChapterMatcher.findChapterGaps(rawMarkers);
      if (gaps.isEmpty) return;

      final missingTotal =
          gaps.fold<int>(0, (n, g) => n + g.missingNumbers.length);

      yield StructureDetectionEvent(
        progress: _progress(
          status: 'Buscando capítulos faltantes',
          detail: gaps.length == 1
              ? 'Hueco ${gaps.first.fromNumber}→${gaps.first.toNumber}: '
                  'reanalizando ${gaps.first.missingNumbers.length} capítulo(s) '
                  'intermedio(s) (pasada ${round + 1}).'
              : '$missingTotal capítulo(s) salteado(s) en ${gaps.length} huecos; '
                  'reanalizando ventanas intermedias (pasada ${round + 1}).',
          phaseLabel: 'Capítulos faltantes',
          overall: 0.90 + round * 0.02,
          phase: 0.0,
          markers: published(),
        ),
        markers: published(),
      );

      var foundAny = false;
      var scanned = 0;
      final workItems = <({int targetNum, int sampleMs, Set<int> expected})>[];

      for (final gap in gaps) {
        final missing = gap.missingNumbers;
        if (missing.isEmpty) continue;
        final span = gap.toPositionMs - gap.fromPositionMs;
        for (var mi = 0; mi < missing.length; mi++) {
          final segStart =
              gap.fromPositionMs + (span * mi / missing.length).round();
          final segEnd =
              gap.fromPositionMs + (span * (mi + 1) / missing.length).round();
          final segSpan = (segEnd - segStart).clamp(1, span);
          for (var s = 0; s < samplesPerMissing; s++) {
            final sampleMs = segStart +
                (segSpan * (s + 1) / (samplesPerMissing + 1)).round();
            workItems.add((
              targetNum: missing[mi],
              sampleMs: sampleMs,
              expected: missing.toSet(),
            ));
          }
        }
      }

      final foundTargets = <int>{};
      for (var wi = 0; wi < workItems.length; wi++) {
        await _waitIfPaused();
        _throwIfCancelled();

        final item = workItems[wi];
        if (foundTargets.contains(item.targetNum)) continue;

        scanned++;
        final loc = _locateAbsoluteMs(files, durations, item.sampleMs);
        if (loc == null) continue;

        yield StructureDetectionEvent(
          progress: _progress(
            status: 'Buscando capítulos faltantes',
            detail:
                'Reanalizando ${_formatClock(item.sampleMs / 1000.0)} '
                '(buscando capítulo ${item.targetNum}; '
                'muestra $scanned/${workItems.length}).',
            phaseLabel: 'Capítulos faltantes',
            overall: 0.90 + round * 0.02 + (wi + 1) / workItems.length * 0.04,
            phase: (wi + 1) / workItems.length,
            markers: published(),
          ),
          markers: published(),
          checkpoint: makeCp(
            files: files,
            durations: durations,
            fileIndex: files.length,
            candidateIndex: 0,
            timelineOffsetSec: durations.fold(0.0, (a, b) => a + b),
            clearCandidates: true,
          ),
        );

        final text = await _transcribeWindow(loc.path, loc.localSec);
        if (text == null || text.trim().isEmpty) {
          await _yieldToEventLoop();
          continue;
        }

        final marker = matcher.matchExpected(
          text,
          item.sampleMs,
          item.expected,
        );
        if (marker != null) {
          final n = KeywordChapterMatcher.parseChapterNumber(marker.label);
          rawMarkers.add(marker);
          foundAny = true;
          if (n != null) foundTargets.add(n);
        }
        await _yieldToEventLoop();
      }

      if (!foundAny) return;
    }
  }

  /// Maps absolute timeline ms to a file path and local start seconds.
  ({String path, double localSec})? _locateAbsoluteMs(
    List<String> files,
    List<double> durations,
    int absoluteMs,
  ) {
    if (files.isEmpty || files.length != durations.length) return null;
    var offsetSec = 0.0;
    final absSec = absoluteMs / 1000.0;
    for (var i = 0; i < files.length; i++) {
      final dur = durations[i];
      if (absSec <= offsetSec + dur || i == files.length - 1) {
        final local = (absSec - offsetSec).clamp(0.0, (dur - 0.5).clamp(0.0, dur));
        return (path: files[i], localSec: local);
      }
      offsetSec += dur;
    }
    return null;
  }

  Stream<StructureDetectionEvent> _prepareModel(
    List<DetectedMarker> Function() published,
  ) async* {
    _modelProgress = 0;
    _modelStatus = 'Preparando modelo';
    _modelDetail =
        'Comprobando si Whisper tiny está instalado en el dispositivo.';

    yield StructureDetectionEvent(
      progress: _progress(
        status: _modelStatus,
        detail: _modelDetail,
        phaseLabel: 'Modelo de voz',
        overall: 0.02,
        phase: 0.0,
        markers: published(),
      ),
      markers: published(),
    );

    final modelFuture = modelManager.ensureModel(
      isCancelled: () => _cancelled,
      onProgress: (p, status, detail) {
        _modelProgress = p;
        _modelStatus = status;
        _modelDetail = detail;
      },
    );

    while (true) {
      await _waitIfPaused();
      _throwIfCancelled();
      final done = await Future.any([
        modelFuture.then<bool>(
          (_) => true,
          onError: (_, _) => true,
        ),
        Future<bool>.delayed(const Duration(milliseconds: 200), () => false),
      ]);
      yield StructureDetectionEvent(
        progress: _progress(
          status: _modelStatus,
          detail: _modelDetail,
          phaseLabel: 'Modelo de voz',
          overall: 0.02 + _modelProgress * 0.16,
          phase: _modelProgress,
          markers: published(),
        ),
        markers: published(),
      );
      if (done) break;
      await _yieldToEventLoop();
    }

    await modelFuture;
    await _waitIfPaused();
    _throwIfCancelled();

    yield StructureDetectionEvent(
      progress: _progress(
        status: 'Cargando reconocedor',
        detail:
            'Inicializando Whisper en isolate (~${windowSeconds.toInt()} s por ventana).',
        phaseLabel: 'Modelo de voz',
        overall: 0.20,
        phase: 1.0,
        markers: published(),
      ),
      markers: published(),
    );
    await _ensureWorker(_language);
    await _waitIfPaused();
    _throwIfCancelled();
  }

  Future<List<Chapter>> markersToChapters(
    Audiobook book,
    List<DetectedMarker> markers,
  ) async {
    double total = 0;
    final files =
        book.files.isNotEmpty ? book.files : await _discoverAudioFiles(book.path);
    for (final f in files) {
      total += await silenceFinder.getDurationSeconds(f);
    }
    if (total <= 0 && book.chapters.isNotEmpty) {
      total = book.chapters.last.end;
    }
    return chaptersFromMarkers(
      markers,
      total,
      AudiobookScanner.formatDuration,
    );
  }

  Future<String?> _transcribeWindow(String audioPath, double startSec) async {
    final tmpDir = await getTemporaryDirectory();
    final pcmPath = p.join(
      tmpDir.path,
      'struct_${DateTime.now().microsecondsSinceEpoch}.pcm',
    );
    final pcmFile = File(pcmPath);

    try {
      final cmd =
          '-y -ss $startSec -t $windowSeconds -i ${_quote(audioPath)} '
          '-ar $sampleRate -ac 1 -f s16le ${_quote(pcmPath)}';
      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code) || !await pcmFile.exists()) {
        return null;
      }

      final length = await pcmFile.length();
      if (length < sampleRate) return null;

      return await _worker!.transcribe(
        pcmPath: pcmPath,
        sampleRate: sampleRate,
      );
    } finally {
      if (await pcmFile.exists()) {
        try {
          await pcmFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<String>> _discoverAudioFiles(String bookPath) async {
    const exts = {'.m4b', '.m4a', '.mp3'};
    final dir = Directory(bookPath);
    if (!await dir.exists()) {
      final f = File(bookPath);
      if (await f.exists()) return [bookPath];
      return [];
    }
    final files = await dir
        .list(recursive: true)
        .where(
          (e) =>
              e is File && exts.contains(p.extension(e.path).toLowerCase()),
        )
        .map((e) => e.path)
        .toList();
    files.sort();
    return files;
  }

  static String _quote(String path) {
    if (path.contains(' ') || path.contains("'")) {
      return "'${path.replaceAll("'", "'\\''")}'";
    }
    return path;
  }
}
