import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audiobook_player/bloc/home_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ticket 01: BLoC & Storage Categories Integration', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
    });

    test('getAllCategories retrieves all CategoryNodes ordered by lft ASC', () async {
      await storage.insertCategory(const CategoryNode(
        name: 'Brandon Sanderson',
        lft: 1,
        rgt: 4,
        depth: 0,
        pathPrefix: 'Brandon Sanderson',
      ));

      final categories = await storage.getAllCategories();
      expect(categories, isNotEmpty);
      expect(categories.first.name, equals('Brandon Sanderson'));
    });

    test('HomeState includes categories list in copyWith and props', () {
      const state = HomeState();
      expect(state.categories, isEmpty);

      const node = CategoryNode(
        id: 1,
        name: 'Cosmere',
        lft: 1,
        rgt: 2,
        depth: 0,
        pathPrefix: 'Cosmere',
      );

      final updated = state.copyWith(categories: [node]);
      expect(updated.categories.length, equals(1));
      expect(updated.categories.first.name, equals('Cosmere'));
    });
  });
}
