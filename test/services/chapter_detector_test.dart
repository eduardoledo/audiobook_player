import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/services/chapter_detector.dart';

void main() {
  group('ChapterDetector (Candidate 2 Seam)', () {
    test('exposes a deep single-entry point interface for chapter detection', () async {
      const detector = ChapterDetector();
      final chapters = await detector.detectChapters(
        audioPath: '/storage/audiobooks/sample.m4b',
        ebookPath: '/storage/ebooks/sample.epub',
      );

      expect(chapters, isA<List>());
    });

    test('returns embedded TOC directly if provided', () async {
      const detector = ChapterDetector();
      final embedded = <Chapter>[
        ChapterDetector.createChapter(
          index: 0,
          start: 0.0,
          end: 120.0,
          title: 'Prologue',
        ),
        ChapterDetector.createChapter(
          index: 1,
          start: 120.0,
          end: 600.0,
          title: 'Chapter 1',
        ),
      ];

      final chapters = await detector.detectChapters(
        audioPath: '/storage/audiobooks/sample.m4b',
        embeddedToc: embedded,
      );

      expect(chapters.length, 2);
      expect(chapters.first.title, 'Prologue');
      expect(chapters.last.title, 'Chapter 1');
    });

    test('returns empty list if non-existent audio file', () async {
      const detector = ChapterDetector();
      final chapters = await detector.detectChapters(
        audioPath: '/non/existent/audio.mp3',
      );

      expect(chapters, isEmpty);
    });
  });
}
