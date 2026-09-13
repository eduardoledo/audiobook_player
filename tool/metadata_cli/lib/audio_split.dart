import 'dart:io';

import 'package:path/path.dart' as p;

import 'path_metadata.dart';
import 'structure_match.dart';

/// Sanitizes a filename segment.
String sanitizeFileSegment(String name) {
  var s = name.trim();
  s = s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? 'chapter' : s;
}

/// Builds an output basename for a chapter cut (no extension).
///
/// Patterns:
/// - with part: `{Part} - {Title}`
/// - without: `{Title}`
///
/// No sequential index — inserting a missing chapter must not force renames.
String chapterOutputBasename(AlignedChapterCut cut) {
  final title = sanitizeFileSegment(cut.epub.title);
  final part = cut.epub.part;
  if (part != null && part.trim().isNotEmpty) {
    return '${sanitizeFileSegment(part)} - $title';
  }
  return title;
}

/// Returns duplicate output basenames (case-insensitive), if any.
///
/// Used before split / fill-missing so two chapters never overwrite the same file.
List<String> duplicateChapterBasenames(Iterable<AlignedChapterCut> cuts) {
  final seen = <String, String>{}; // lower → first basename
  final dupes = <String>{};
  for (final cut in cuts) {
    final base = chapterOutputBasename(cut);
    final key = base.toLowerCase();
    if (seen.containsKey(key)) {
      dupes.add(seen[key]!);
      if (seen[key] != base) dupes.add(base);
    } else {
      seen[key] = base;
    }
  }
  final out = dupes.toList()..sort();
  return out;
}

/// Throws if two cuts would produce the same output filename.
void ensureUniqueChapterBasenames(Iterable<AlignedChapterCut> cuts) {
  final dupes = duplicateChapterBasenames(cuts);
  if (dupes.isEmpty) return;
  throw StateError(
    'Duplicate chapter output names (add distinct titles/parts): '
    '${dupes.map((d) => '"$d"').join(', ')}',
  );
}

class SplitResult {
  final List<String> outputFiles;
  final List<AlignedChapterCut> cuts;
  final String originalsDir;

  const SplitResult({
    required this.outputFiles,
    required this.cuts,
    required this.originalsDir,
  });
}

/// Moves [audioPath] into `bookPath/originalsDirName/` and splits cuts with ffmpeg.
Future<SplitResult> splitAudioByCuts({
  required String bookPath,
  required String audioPath,
  required List<AlignedChapterCut> cuts,
  String originalsDirName = 'originals',
  bool dryRun = false,
  void Function(String msg)? onLog,
}) async {
  if (cuts.isEmpty) {
    throw ArgumentError('No cuts to split');
  }
  ensureUniqueChapterBasenames(cuts);
  final originalsDir = Directory(p.join(bookPath, originalsDirName));
  final ext = p.extension(audioPath).isEmpty ? '.m4b' : p.extension(audioPath);
  final planned = <String>[];
  for (var i = 0; i < cuts.length; i++) {
    planned.add(
      p.join(bookPath, '${chapterOutputBasename(cuts[i])}$ext'),
    );
  }

  if (dryRun) {
    onLog?.call('Dry-run: would move $audioPath → ${originalsDir.path}/');
    for (final f in planned) {
      onLog?.call('Dry-run: would write $f');
    }
    return SplitResult(
      outputFiles: planned,
      cuts: cuts,
      originalsDir: originalsDir.path,
    );
  }

  if (!await originalsDir.exists()) {
    await originalsDir.create(recursive: true);
  }
  final destOriginal = p.join(originalsDir.path, p.basename(audioPath));
  if (p.normalize(audioPath) != p.normalize(destOriginal)) {
    onLog?.call('Archiving original → $destOriginal');
    await File(audioPath).rename(destOriginal);
  }
  final sourceForSplit = destOriginal;

  final ffmpeg = await _which('ffmpeg');
  if (ffmpeg == null) throw StateError('ffmpeg not found on PATH');

  final written = <String>[];
  for (var i = 0; i < cuts.length; i++) {
    final cut = cuts[i];
    final out = planned[i];
    final start = cut.startSeconds;
    final dur = (cut.endSeconds - cut.startSeconds).clamp(0.1, double.infinity);
    onLog?.call(
      'Splitting ${i + 1}/${cuts.length}: ${p.basename(out)} '
      '(${start.toStringAsFixed(1)}s + ${dur.toStringAsFixed(1)}s)',
    );
    // -ss after -i is more accurate; stream copy when possible.
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-y',
      '-i',
      sourceForSplit,
      '-ss',
      start.toStringAsFixed(3),
      '-t',
      dur.toStringAsFixed(3),
      '-c',
      'copy',
      '-map',
      '0:a:0?',
      '-map_chapters',
      '-1',
      out,
    ]);
    if (result.exitCode != 0) {
      // Retry with re-encode if copy fails at keyframe boundaries.
      onLog?.call('  copy failed, re-encoding AAC…');
      final r2 = await Process.run(ffmpeg, [
        '-hide_banner',
        '-y',
        '-ss',
        start.toStringAsFixed(3),
        '-t',
        dur.toStringAsFixed(3),
        '-i',
        sourceForSplit,
        '-c:a',
        'aac',
        '-b:a',
        '64k',
        '-map_chapters',
        '-1',
        out,
      ]);
      if (r2.exitCode != 0) {
        throw StateError(
          'ffmpeg split failed for $out: ${r2.stderr}',
        );
      }
    }
    written.add(out);
  }

  return SplitResult(
    outputFiles: written,
    cuts: cuts,
    originalsDir: originalsDir.path,
  );
}

/// Builds chapter JSON maps for metadata (one chapter per file after split).
List<Map<String, dynamic>> chaptersFromSplitFiles({
  required List<AlignedChapterCut> cuts,
  required List<String> outputFiles,
  required List<double> fileDurationsSeconds,
}) {
  final chapters = <Map<String, dynamic>>[];
  var cursor = 0.0;
  for (var i = 0; i < cuts.length; i++) {
    final cut = cuts[i];
    final dur = i < fileDurationsSeconds.length
        ? fileDurationsSeconds[i]
        : (cut.endSeconds - cut.startSeconds);
    final start = cursor;
    final end = cursor + dur;
    cursor = end;
    final title = cut.epub.title;
    chapters.add({
      'index': i,
      'title': title,
      'displayTitle': title,
      'start': start,
      'end': end,
      'duration': dur,
      'startFormatted': formatDuration(start),
      'endFormatted': formatDuration(end),
      'durationFormatted': formatDuration(dur),
      if (cut.epub.part != null) 'part': cut.epub.part,
    });
  }
  return chapters;
}

/// Chapter maps when not splitting (timeline within single file).
List<Map<String, dynamic>> chaptersFromCutsTimeline(
  List<AlignedChapterCut> cuts,
) {
  final chapters = <Map<String, dynamic>>[];
  for (var i = 0; i < cuts.length; i++) {
    final cut = cuts[i];
    final dur = cut.endSeconds - cut.startSeconds;
    chapters.add({
      'index': i,
      'title': cut.epub.title,
      'displayTitle': cut.epub.title,
      'start': cut.startSeconds,
      'end': cut.endSeconds,
      'duration': dur,
      'startFormatted': formatDuration(cut.startSeconds),
      'endFormatted': formatDuration(cut.endSeconds),
      'durationFormatted': formatDuration(dur),
      if (cut.epub.part != null) 'part': cut.epub.part,
    });
  }
  return chapters;
}

Future<String?> _which(String name) async {
  final r = await Process.run('which', [name]);
  if (r.exitCode != 0) return null;
  final path = (r.stdout as String).trim();
  return path.isEmpty ? null : path;
}

/// Splits one already-exported chapter file at [cutSeconds] into two files.
///
/// Writes [previousOutPath] (0→cut) and [missingOutPath] (cut→end). If
/// [previousOutPath] equals [sourcePath], replaces the source via a temp file.
Future<void> splitOneFileAtCut({
  required String sourcePath,
  required double cutSeconds,
  required String previousOutPath,
  required String missingOutPath,
  void Function(String msg)? onLog,
}) async {
  final ffmpeg = await _which('ffmpeg');
  if (ffmpeg == null) throw StateError('ffmpeg not found on PATH');
  final duration = await _probeDuration(sourcePath);
  if (duration <= 0) throw StateError('Could not probe duration of $sourcePath');
  if (cutSeconds < 1 || cutSeconds > duration - 1) {
    throw StateError(
      'Cut ${cutSeconds.toStringAsFixed(1)}s out of range for '
      '${p.basename(sourcePath)} (${duration.toStringAsFixed(1)}s)',
    );
  }

  final dir = Directory.systemTemp.createTempSync('metadata_cli_resplit_');
  final tmpPrev = p.join(dir.path, 'prev${p.extension(sourcePath)}');
  final tmpMiss = p.join(dir.path, 'miss${p.extension(sourcePath)}');
  try {
    onLog?.call(
      'Re-splitting ${p.basename(sourcePath)} @ '
      '${cutSeconds.toStringAsFixed(1)}s → '
      '${p.basename(previousOutPath)} + ${p.basename(missingOutPath)}',
    );
    await _ffmpegExtractSegment(
      ffmpeg: ffmpeg,
      sourcePath: sourcePath,
      startSeconds: 0,
      durationSeconds: cutSeconds,
      outPath: tmpPrev,
      onLog: onLog,
    );
    await _ffmpegExtractSegment(
      ffmpeg: ffmpeg,
      sourcePath: sourcePath,
      startSeconds: cutSeconds,
      durationSeconds: duration - cutSeconds,
      outPath: tmpMiss,
      onLog: onLog,
    );

    if (p.normalize(previousOutPath) == p.normalize(sourcePath)) {
      await File(sourcePath).delete();
    }
    await File(tmpPrev).copy(previousOutPath);
    await File(tmpMiss).copy(missingOutPath);
    if (p.normalize(previousOutPath) != p.normalize(sourcePath) &&
        File(sourcePath).existsSync()) {
      await File(sourcePath).delete();
    }
  } finally {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

Future<void> _ffmpegExtractSegment({
  required String ffmpeg,
  required String sourcePath,
  required double startSeconds,
  required double durationSeconds,
  required String outPath,
  void Function(String msg)? onLog,
}) async {
  final result = await Process.run(ffmpeg, [
    '-hide_banner',
    '-y',
    '-i',
    sourcePath,
    '-ss',
    startSeconds.toStringAsFixed(3),
    '-t',
    durationSeconds.toStringAsFixed(3),
    '-c',
    'copy',
    '-map',
    '0:a:0?',
    '-map_chapters',
    '-1',
    outPath,
  ]);
  if (result.exitCode == 0 && await File(outPath).exists() && await File(outPath).length() > 100) {
    return;
  }
  onLog?.call('  copy failed, re-encoding AAC…');
  final r2 = await Process.run(ffmpeg, [
    '-hide_banner',
    '-y',
    '-ss',
    startSeconds.toStringAsFixed(3),
    '-t',
    durationSeconds.toStringAsFixed(3),
    '-i',
    sourcePath,
    '-c:a',
    'aac',
    '-b:a',
    '64k',
    '-map_chapters',
    '-1',
    outPath,
  ]);
  if (r2.exitCode != 0) {
    throw StateError('ffmpeg extract failed for $outPath: ${r2.stderr}');
  }
}

Future<double> _probeDuration(String audioPath) async {
  final ffprobe = await _which('ffprobe');
  if (ffprobe == null) return 0;
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
