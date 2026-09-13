import 'dart:io';

import 'package:metadata_cli/chapter_phrase_locator.dart';
import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/proximity_windows.dart';
import 'package:path/path.dart' as p;

/// Focused experiment: locate prologue (and optionally first N chapters).
Future<void> main(List<String> args) async {
  final book = args.isNotEmpty
      ? args[0]
      : '/home/eduardo/Descargas/Books/Audiobooks/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire';
  final audio = p.join(book, '01 - The Final Empire.m4b');
  final epubPath = p.join(book, 'The Final Empire by Brandon Sanderson.epub');
  final limit = args.length > 1 ? int.parse(args[1]) : 1;

  final epub = parseEpubStructure(epubPath);
  final entries = epub.entries.take(limit).toList();
  final totalBookWords =
      epub.entries.fold<int>(0, (a, e) => a + (e.wordCount > 0 ? e.wordCount : 1));
  final duration = await probeDurationSeconds(audio);
  stdout.writeln(
    'duration=${_fmt(duration)} entries=${entries.length}/'
    '${epub.entries.length} (bookWords=$totalBookWords)',
  );
  for (final e in entries) {
    stdout.writeln(
      '  ${e.title} words=${e.wordCount} «${e.firstWords}»',
    );
  }

  final locator = ChapterPhraseLocator(fast: true);
  final sw = Stopwatch()..start();
  final cuts = await locator.locate(
    audioPath: audio,
    entries: entries,
    durationSeconds: duration,
    totalBookWords: totalBookWords,
    onLog: stdout.writeln,
  );
  sw.stop();

  stdout.writeln('\n=== RESULT (${sw.elapsed}) ===');
  for (var i = 0; i < cuts.length; i++) {
    final c = cuts[i];
    if (c == null) {
      stdout.writeln('  ${entries[i].title}: NOT FOUND');
    } else {
      stdout.writeln(
        '  ${entries[i].title}: ${_fmt(c.startSeconds)} '
        '(expect ~${_fmt(_expected(entries, duration, totalBookWords, i))})',
      );
    }
  }

  // Prologue should be near ~70s (after dedication), not 0.
  if (limit >= 1) {
    final p0 = cuts[0];
    if (p0 == null) {
      stderr.writeln('FAIL: prologue not found');
      exitCode = 1;
    } else if (p0.startSeconds < 30 || p0.startSeconds > 180) {
      stderr.writeln(
        'FAIL: prologue at ${_fmt(p0.startSeconds)}, expected ~01:00–01:30',
      );
      exitCode = 2;
    } else {
      stdout.writeln('PASS: prologue in expected band');
    }
  }
  if (limit >= 2) {
    final c1 = cuts[1];
    if (c1 == null) {
      stderr.writeln('FAIL: chapter 1 not found');
      exitCode = 3;
    } else if (c1.startSeconds < 30 * 60 || c1.startSeconds > 50 * 60) {
      stderr.writeln(
        'FAIL: chapter 1 at ${_fmt(c1.startSeconds)}, expected ~00:35–00:45',
      );
      exitCode = 4;
    } else {
      stdout.writeln('PASS: chapter 1 in expected band');
    }
  }
}

double _expected(
  List<EpubTocEntry> entries,
  double duration,
  int totalBookWords,
  int i,
) {
  final wins = buildProximityWindows(
    entries: entries,
    durationSeconds: duration,
    totalBookWords: totalBookWords,
  );
  return wins[i].expectedStart;
}

String _fmt(double s) {
  final sec = s.round().clamp(0, 1 << 30);
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final r = sec % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${r.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:'
      '${r.toString().padLeft(2, '0')}';
}
