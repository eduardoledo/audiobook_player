import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiobook_player/models/bookmark.dart';
import 'package:audiobook_player/services/library_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Rich Bookmark Storage Persistence (Ticket 05)', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
    });

    test('persists and retrieves rich bookmarks with textNote and audioNotePath in SQLite', () async {
      final bookPath = '/storage/books/Cosmere_${DateTime.now().millisecondsSinceEpoch}';

      final bookmark = Bookmark(
        bookPath: bookPath,
        positionMs: 60000,
        label: 'Important Clue',
        textNote: 'Hoid appears here',
        audioNotePath: '/recordings/note_hoid.aac',
        createdAt: DateTime.now(),
      );

      final id = await storage.addBookmark(bookmark);
      expect(id, greaterThan(0));

      final bookmarks = await storage.getBookmarksForBook(bookPath);
      expect(bookmarks.length, equals(1));
      expect(bookmarks.first.label, equals('Important Clue'));
      expect(bookmarks.first.textNote, equals('Hoid appears here'));
      expect(bookmarks.first.audioNotePath, equals('/recordings/note_hoid.aac'));
    });
  });
}
