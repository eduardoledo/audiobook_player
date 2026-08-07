import 'detected_marker.dart';

enum StructureDetectionJobStatus {
  idle,
  running,
  paused,
  completed,
  error,
}

/// In-memory resume point for structure detection.
class StructureDetectionCheckpoint {
  final List<String> files;
  final List<double> durations;
  final int fileIndex;

  /// Next candidate index to process within [candidatesForFile].
  final int candidateIndex;

  /// Null means silence scan for this file must run again.
  final List<double>? candidatesForFile;
  final double timelineOffsetSec;
  final List<DetectedMarker> rawMarkers;
  final bool modelReady;

  /// Whisper language code: `es`, `en`, or `''` for auto.
  final String language;

  const StructureDetectionCheckpoint({
    required this.files,
    required this.durations,
    required this.fileIndex,
    required this.candidateIndex,
    required this.candidatesForFile,
    required this.timelineOffsetSec,
    required this.rawMarkers,
    this.modelReady = true,
    this.language = 'es',
  });

  StructureDetectionCheckpoint copyWith({
    List<String>? files,
    List<double>? durations,
    int? fileIndex,
    int? candidateIndex,
    List<double>? candidatesForFile,
    bool clearCandidates = false,
    double? timelineOffsetSec,
    List<DetectedMarker>? rawMarkers,
    bool? modelReady,
    String? language,
  }) {
    return StructureDetectionCheckpoint(
      files: files ?? this.files,
      durations: durations ?? this.durations,
      fileIndex: fileIndex ?? this.fileIndex,
      candidateIndex: candidateIndex ?? this.candidateIndex,
      candidatesForFile:
          clearCandidates ? null : (candidatesForFile ?? this.candidatesForFile),
      timelineOffsetSec: timelineOffsetSec ?? this.timelineOffsetSec,
      rawMarkers: rawMarkers ?? this.rawMarkers,
      modelReady: modelReady ?? this.modelReady,
      language: language ?? this.language,
    );
  }
}

/// One yield from the detection generator.
class StructureDetectionEvent {
  final StructureDetectionProgress progress;
  final List<DetectedMarker> markers;
  final StructureDetectionCheckpoint? checkpoint;
  final bool done;

  const StructureDetectionEvent({
    required this.progress,
    this.markers = const [],
    this.checkpoint,
    this.done = false,
  });
}
