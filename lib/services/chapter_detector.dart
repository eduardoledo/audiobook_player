import '../models/audiobook.dart';

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

  const ChapterDetector({
    this.options = const ChapterDetectorOptions(),
  });

  /// Single high-leverage entry point for analyzing an audio file or folder
  /// and returning confirmed chapter structures.
  Future<List<Chapter>> detectChapters({
    required String audioPath,
    String? ebookPath,
  }) async {
    // 1. If embedded TOC exists (M4B), return TOC chapters
    // 2. Otherwise run silence candidate finder
    // 3. If ebookPath provided and alignment enabled, cross-reference silence breaks with eBook text
    // 4. Fallback gracefully to default numbered chapters if alignment fails
    return const [];
  }
}
