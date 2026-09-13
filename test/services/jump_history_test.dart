import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiobook_player/services/library_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('JumpHistory LIFO Stack (Ticket 03)', () {
    late LibraryStorage storage;

    setUp(() {
      storage = LibraryStorage();
    });

    test('pushes and pops jump positions in LIFO order per book', () async {
      const bookPath = '/storage/books/Mistborn';

      await storage.pushJump(bookPath: bookPath, positionMs: 10000);
      await storage.pushJump(bookPath: bookPath, positionMs: 45000);
      await storage.pushJump(bookPath: bookPath, positionMs: 90000);

      final pop1 = await storage.popJump(bookPath: bookPath);
      final pop2 = await storage.popJump(bookPath: bookPath);

      expect(pop1, equals(90000));
      expect(pop2, equals(45000));
    });

    test('evicts oldest jump entries when exceeding maximum limit of 20 items', () async {
      const bookPath = '/storage/books/WayOfKings';

      // Push 25 entries (1000 to 25000)
      for (int i = 1; i <= 25; i++) {
        await storage.pushJump(bookPath: bookPath, positionMs: i * 1000);
      }

      final history = await storage.getJumpHistory(bookPath: bookPath);
      expect(history.length, equals(20));
      expect(history.first, equals(25000)); // Newest
      expect(history.last, equals(6000));   // Oldest remaining (1..5 evicted)
    });
  });
}
