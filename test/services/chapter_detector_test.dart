import 'package:flutter_test/flutter_test.dart';
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
  });
}
