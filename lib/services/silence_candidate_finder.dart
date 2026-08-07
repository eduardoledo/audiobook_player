import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_audio/statistics.dart';

/// Finds silence-based candidate timestamps (seconds) for structure ASR windows.
class SilenceCandidateFinder {
  /// Minimum silence duration (seconds) to count as a boundary.
  final double minSilenceSeconds;

  /// Noise threshold for silencedetect (dB).
  final String noiseDb;

  /// If fewer than this many silences, add periodic samples.
  final int minCandidates;

  /// Periodic fallback interval (seconds).
  final double fallbackIntervalSeconds;

  /// Minimum gap between silence candidates after thinning.
  final double minGapSeconds;

  const SilenceCandidateFinder({
    this.minSilenceSeconds = 1.2,
    this.noiseDb = '-30dB',
    this.minCandidates = 6,
    this.fallbackIntervalSeconds = 480,
    this.minGapSeconds = 20,
  });

  Future<double> getDurationSeconds(String audioPath) async {
    final session = await FFprobeKit.getMediaInformation(audioPath);
    final info = session.getMediaInformation();
    final durationStr = info?.getDuration();
    if (durationStr == null) return 0;
    return double.tryParse(durationStr) ?? 0;
  }

  /// Returns candidate start times in seconds (includes 0.0).
  ///
  /// [onProgress] receives 0..1 based on FFmpeg processed time / media duration
  /// while silencedetect runs.
  Future<List<double>> findCandidates(
    String audioPath, {
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    if (isCancelled?.call() == true) throw StateError('cancelled');

    final duration = await getDurationSeconds(audioPath);
    final silenceEnds = <double>[];

    final cmd =
        '-hide_banner -i ${_quote(audioPath)} -af silencedetect=noise=$noiseDb:d=$minSilenceSeconds -f null -';

    onProgress?.call(0.0);

    final session = await _executeWithProgress(
      cmd,
      durationSeconds: duration,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    final returnCode = await session.getReturnCode();
    final logs = await session.getAllLogsAsString() ?? '';

    if (isCancelled?.call() == true) throw StateError('cancelled');

    // silencedetect writes to stderr; FFmpegKit aggregates into logs.
    final silenceEndRe = RegExp(r'silence_end:\s*([\d.]+)');
    for (final m in silenceEndRe.allMatches(logs)) {
      final t = double.tryParse(m.group(1)!);
      if (t != null && t < duration) silenceEnds.add(t);
    }

    // Also pick silence_start as optional (sometimes end missing)
    final silenceStartRe = RegExp(r'silence_start:\s*([\d.]+)');
    for (final m in silenceStartRe.allMatches(logs)) {
      final t = double.tryParse(m.group(1)!);
      if (t != null && t > 0.5 && t < duration) {
        // Window after silence starts ending ~ silence + gap; use end of silence approx
        silenceEnds.add(t + minSilenceSeconds);
      }
    }

    if (!ReturnCode.isSuccess(returnCode) && silenceEnds.isEmpty) {
      // Fall through to periodic sampling only
    }

    final candidates = <double>{0.0};
    for (final t in silenceEnds) {
      if (t >= 0 && t < duration - 0.5) candidates.add(t);
    }

    if (candidates.length < minCandidates && duration > 0) {
      for (var t = fallbackIntervalSeconds;
          t < duration - 1;
          t += fallbackIntervalSeconds) {
        candidates.add(t);
      }
    }

    onProgress?.call(1.0);

    final sorted = candidates.toList()..sort();
    return _thin(sorted, minGapSeconds: minGapSeconds);
  }

  /// Runs FFmpeg asynchronously so statistics callbacks can report progress.
  Future<FFmpegSession> _executeWithProgress(
    String cmd, {
    required double durationSeconds,
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
  }) async {
    final completer = Completer<FFmpegSession>();
    var lastReported = -1.0;
    int? sessionId;

    void reportFromStats(Statistics stats) {
      if (durationSeconds <= 0) return;
      // FFmpegKit reports processed time in milliseconds.
      final timeMs = stats.getTime();
      if (timeMs <= 0) return;
      final p = (timeMs / 1000.0 / durationSeconds).clamp(0.0, 0.99);
      // Throttle UI updates (~1% steps).
      if (p - lastReported < 0.01 && p < 0.99) return;
      lastReported = p;
      onProgress?.call(p);
    }

    final session = await FFmpegKit.executeAsync(
      cmd,
      (completed) {
        if (!completer.isCompleted) completer.complete(completed);
      },
      null,
      (stats) {
        sessionId ??= stats.getSessionId();
        reportFromStats(stats);
        if (isCancelled?.call() == true && sessionId != null) {
          FFmpegKit.cancel(sessionId);
        }
      },
    );
    sessionId = session.getSessionId();

    // Poll cancel in case statistics are sparse (e.g. short files).
    Timer? cancelPoll;
    if (isCancelled != null) {
      cancelPoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (isCancelled() && sessionId != null) {
          FFmpegKit.cancel(sessionId);
        }
      });
    }

    try {
      return await completer.future;
    } finally {
      cancelPoll?.cancel();
    }
  }

  List<double> _thin(List<double> times, {required double minGapSeconds}) {
    if (times.isEmpty) return times;
    final out = <double>[times.first];
    for (var i = 1; i < times.length; i++) {
      if (times[i] - out.last >= minGapSeconds) out.add(times[i]);
    }
    return out;
  }

  static String _quote(String path) {
    if (path.contains(' ') || path.contains("'")) {
      return "'${path.replaceAll("'", "'\\''")}'";
    }
    return path;
  }
}
