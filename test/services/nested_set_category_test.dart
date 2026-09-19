import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ticket 02: Nested Set Tree Operations & Invariants', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
      final db = await storage.database;
      await db.delete('categories');
    });

    test('insertCategory and rebuildNestedSet maintain lft < rgt and correct depth invariant', () async {
      final rootId = await storage.insertCategory(const CategoryNode(
        name: 'Brandon Sanderson',
        lft: 0,
        rgt: 0,
        depth: 0,
        pathPrefix: 'Brandon Sanderson',
      ));

      final cosmereId = await storage.insertCategory(CategoryNode(
        name: 'Cosmere',
        lft: 0,
        rgt: 0,
        depth: 0,
        parentId: rootId,
        pathPrefix: 'Brandon Sanderson/Cosmere',
      ));

      final mistbornId = await storage.insertCategory(CategoryNode(
        name: 'Mistborn Era 1',
        lft: 0,
        rgt: 0,
        depth: 0,
        parentId: cosmereId,
        pathPrefix: 'Brandon Sanderson/Cosmere/Mistborn Era 1',
      ));

      expect(rootId, greaterThan(0));
      expect(cosmereId, greaterThan(0));
      expect(mistbornId, greaterThan(0));

      final subtree = await storage.getCategoriesSubtree(rootId);
      expect(subtree.length, equals(3));

      final root = subtree.firstWhere((CategoryNode c) => c.id == rootId);
      final cosmere = subtree.firstWhere((CategoryNode c) => c.id == cosmereId);
      final mistborn = subtree.firstWhere((CategoryNode c) => c.id == mistbornId);

      // Invariants: lft < rgt and rgt - lft = 2 * descendants + 1
      expect(root.lft, equals(1));
      expect(root.rgt, equals(6));
      expect(root.depth, equals(0));
      expect(root.rgt - root.lft, equals(2 * 2 + 1));

      expect(cosmere.lft, equals(2));
      expect(cosmere.rgt, equals(5));
      expect(cosmere.depth, equals(1));
      expect(cosmere.rgt - cosmere.lft, equals(2 * 1 + 1));

      expect(mistborn.lft, equals(3));
      expect(mistborn.rgt, equals(4));
      expect(mistborn.depth, equals(2));
      expect(mistborn.rgt - mistborn.lft, equals(2 * 0 + 1));
    });
  });
}
