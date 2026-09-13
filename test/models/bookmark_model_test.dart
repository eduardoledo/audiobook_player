import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/bookmark.dart';

void main() {
  group('Rich Bookmark Model (Ticket 05)', () {
    test('serializes and deserializes rich bookmark with textNote and audioNotePath', () {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 1,
        bookPath: '/storage/books/Mistborn',
        positionMs: 125000,
        label: 'Climax Scene',
        textNote: 'Check the dialogue at the end of the chapter.',
        audioNotePath: '/recordings/note_1.m4a',
        createdAt: now,
      );

      final map = bookmark.toMap();
      final restored = Bookmark.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.bookPath, equals('/storage/books/Mistborn'));
      expect(restored.positionMs, equals(125000));
      expect(restored.label, equals('Climax Scene'));
      expect(restored.textNote, equals('Check the dialogue at the end of the chapter.'));
      expect(restored.audioNotePath, equals('/recordings/note_1.m4a'));
      expect(restored.positionFormatted, equals('02:05'));
    });
  });
}
