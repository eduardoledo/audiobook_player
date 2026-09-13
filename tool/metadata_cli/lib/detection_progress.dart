import 'dart:io';

/// Terminal progress helper for long-running structure detection.
///
/// Uses stderr + carriage return for live updates; [log] for durable lines.
class DetectionProgress {
  final void Function(String msg)? onLog;
  final Stopwatch _sw = Stopwatch()..start();
  int chaptersTotal = 0;
  int chaptersDone = 0;
  int chaptersFound = 0;
  int chaptersMissing = 0;

  DetectionProgress({this.onLog});

  void log(String msg) {
    _clearLine();
    (onLog ?? stdout.writeln)(msg);
  }

  /// In-place status line (stderr).
  void status(String msg) {
    final cols = _termCols();
    var line = msg.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (line.length >= cols) {
      line = '${line.substring(0, cols - 2)}…';
    }
    stderr.write('\r$line${' ' * (cols - line.length - 1)}');
  }

  void chapterStart({
    required int index1Based,
    required int total,
    required String title,
    required int windowsTotal,
  }) {
    chaptersTotal = total;
    status(
      '${_overallPct()} [$index1Based/$total] $title — '
      '0/$windowsTotal windows · ${_elapsed()}',
    );
  }

  void chapterWindow({
    required int index1Based,
    required int total,
    required String title,
    required int windowIndex1Based,
    required int windowsTotal,
    required double atSeconds,
    String? extra,
  }) {
    final winPct = windowsTotal == 0
        ? 100
        : ((windowIndex1Based / windowsTotal) * 100).floor();
    final suffix = extra == null || extra.isEmpty ? '' : ' · $extra';
    status(
      '${_overallPct()} [$index1Based/$total] $title — '
      'win $windowIndex1Based/$windowsTotal ($winPct%) '
      '@ ${fmtTime(atSeconds)} · found $chaptersFound$suffix · ${_elapsed()}',
    );
  }

  void chapterDone({
    required int index1Based,
    required int total,
    required String title,
    required double? foundAt,
    required bool fuzzy,
  }) {
    chaptersDone = index1Based;
    if (foundAt != null) {
      chaptersFound++;
      log(
        '  ✓ [$index1Based/$total] $title @ ${fmtTime(foundAt)}'
        '${fuzzy ? " (fuzzy)" : ""} · ${_overallPct()} · ${_elapsed()}',
      );
    } else {
      chaptersMissing++;
      log(
        '  ✗ [$index1Based/$total] $title not found · '
        '${_overallPct()} · ${_elapsed()}',
      );
    }
  }

  void silenceProgress(double processedSeconds, double durationSeconds) {
    final pct = durationSeconds <= 0
        ? 0
        : ((processedSeconds / durationSeconds) * 100).clamp(0, 100).floor();
    status(
      'Silence detect $pct% · ${fmtTime(processedSeconds)} / ${fmtTime(durationSeconds)} '
      '· ${_elapsed()}',
    );
  }

  void silenceDone(int candidates) {
    log('Silence detect done: $candidates candidate window(s) · ${_elapsed()}');
  }

  void summary() {
    log(
      'Detection progress: $chaptersFound found, $chaptersMissing missing, '
      '$chaptersDone/$chaptersTotal chapters · ${_elapsed()}',
    );
  }

  String _overallPct() {
    if (chaptersTotal <= 0) return '  0%';
    final pct = ((chaptersDone / chaptersTotal) * 100).floor();
    return '${pct.toString().padLeft(3)}%';
  }

  String _elapsed() {
    final s = _sw.elapsed.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h}h${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m${sec.toString().padLeft(2, '0')}s';
  }

  static String fmtTime(double seconds) {
    final s = seconds.floor();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }

  void _clearLine() {
    final cols = _termCols();
    stderr.write('\r${' ' * (cols - 1)}\r');
  }

  int _termCols() {
    try {
      final cols = stdout.terminalColumns;
      if (cols > 40) return cols;
    } catch (_) {}
    return 100;
  }
}
