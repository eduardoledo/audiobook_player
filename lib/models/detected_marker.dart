import 'audiobook.dart';

enum MarkerType { prologue, part, chapter, epilogue, end }

/// A structure marker found by on-device ASR + keyword matching.
class DetectedMarker {
  final MarkerType type;
  final String label;
  final int positionMs;
  final double confidence;
  final String rawText;

  const DetectedMarker({
    required this.type,
    required this.label,
    required this.positionMs,
    this.confidence = 1.0,
    this.rawText = '',
  });

  DetectedMarker copyWith({
    MarkerType? type,
    String? label,
    int? positionMs,
    double? confidence,
    String? rawText,
  }) {
    return DetectedMarker(
      type: type ?? this.type,
      label: label ?? this.label,
      positionMs: positionMs ?? this.positionMs,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// Progress update emitted while detecting structure.
class StructureDetectionProgress {
  /// Short title for the current phase (e.g. "Buscando silencios").
  final String status;

  /// Longer explanation of what is happening right now.
  final String detail;

  /// Label shown next to the per-task progress bar.
  final String phaseLabel;

  /// Overall pipeline progress 0.0–1.0; null = indeterminate.
  final double? progress;

  /// Current task progress 0.0–1.0; null = indeterminate.
  final double? phaseProgress;

  /// Markers found so far (partial results).
  final List<DetectedMarker> markers;

  final bool paused;
  final bool cancellable;

  const StructureDetectionProgress({
    required this.status,
    this.detail = '',
    String? phaseLabel,
    this.progress,
    this.phaseProgress,
    this.markers = const [],
    this.paused = false,
    this.cancellable = true,
  }) : phaseLabel = phaseLabel ?? status;

  StructureDetectionProgress copyWith({
    String? status,
    String? detail,
    String? phaseLabel,
    double? progress,
    double? phaseProgress,
    List<DetectedMarker>? markers,
    bool? paused,
    bool? cancellable,
  }) {
    return StructureDetectionProgress(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      progress: progress ?? this.progress,
      phaseProgress: phaseProgress ?? this.phaseProgress,
      markers: markers ?? this.markers,
      paused: paused ?? this.paused,
      cancellable: cancellable ?? this.cancellable,
    );
  }
}

/// Builds [Chapter] list from ordered start markers and total duration (seconds).
List<Chapter> chaptersFromMarkers(
  List<DetectedMarker> markers,
  double totalDurationSeconds,
  String Function(double seconds) formatDuration,
) {
  final starts = markers
      .where((m) => m.type != MarkerType.end)
      .toList()
    ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

  if (starts.isEmpty) return const [];

  final chapters = <Chapter>[];
  String? currentPart;

  for (var i = 0; i < starts.length; i++) {
    final m = starts[i];
    if (m.type == MarkerType.part) {
      currentPart = m.label;
    }

    final startSec = m.positionMs / 1000.0;
    final endSec = i + 1 < starts.length
        ? starts[i + 1].positionMs / 1000.0
        : totalDurationSeconds;
    final duration = (endSec - startSec).clamp(0.0, double.infinity);

    chapters.add(Chapter(
      index: i,
      start: startSec,
      end: endSec,
      duration: duration,
      startFormatted: formatDuration(startSec),
      endFormatted: formatDuration(endSec),
      durationFormatted: formatDuration(duration),
      title: m.label,
      displayTitle: currentPart != null && m.type != MarkerType.part
          ? '$currentPart - ${m.label}'
          : m.label,
      part: currentPart,
    ));
  }

  return chapters;
}
