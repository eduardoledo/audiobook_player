import 'dart:convert';
import 'dart:io';

/// A chapter atom embedded in an audio container (M4B/MP4).
class EmbeddedChapter {
  final String title;
  final double startSeconds;
  final double endSeconds;

  const EmbeddedChapter({
    required this.title,
    required this.startSeconds,
    required this.endSeconds,
  });

  double get durationSeconds =>
      (endSeconds - startSeconds).clamp(0.0, double.infinity);
}

/// Reads chapters via system `ffprobe -show_chapters -print_format json`.
Future<List<EmbeddedChapter>> readEmbeddedChapters(String audioPath) async {
  final ffprobe = await _which('ffprobe');
  if (ffprobe == null) {
    throw StateError('ffprobe not found on PATH');
  }
  final result = await Process.run(
    ffprobe,
    [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_chapters',
      audioPath,
    ],
  );
  if (result.exitCode != 0) {
    stderr.writeln('ffprobe failed: ${result.stderr}');
    return [];
  }
  final raw = result.stdout;
  final text = raw is String ? raw : utf8.decode(raw as List<int>);
  if (text.trim().isEmpty) return [];
  final json = jsonDecode(text) as Map<String, dynamic>;
  final list = json['chapters'] as List<dynamic>? ?? const [];
  final out = <EmbeddedChapter>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final start = double.tryParse('${m['start_time']}') ?? 0;
    final end = double.tryParse('${m['end_time']}') ?? start;
    final tags = m['tags'];
    var title = '';
    if (tags is Map) {
      title = '${tags['title'] ?? ''}';
    }
    title = title.trim();
    if (title.isEmpty) title = 'Chapter ${out.length + 1}';
    out.add(
      EmbeddedChapter(
        title: title,
        startSeconds: start,
        endSeconds: end,
      ),
    );
  }
  return out;
}

Future<String?> _which(String name) async {
  final r = await Process.run('which', [name]);
  if (r.exitCode != 0) return null;
  final path = (r.stdout as String).trim();
  return path.isEmpty ? null : path;
}
