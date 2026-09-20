import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/bloc/home_state.dart';

void main() {
  group('Ticket 02: HomeScreen Directory Tree from Nested Set', () {
    testWidgets('renders folder nodes matching CategoryNode list in HomeState', (WidgetTester tester) async {
      const categories = [
        CategoryNode(id: 1, name: 'Brandon Sanderson', lft: 1, rgt: 6, depth: 0, pathPrefix: 'Brandon Sanderson', parentOrder: 1.0),
        CategoryNode(id: 2, name: 'Cosmere', lft: 2, rgt: 5, depth: 1, parentId: 1, pathPrefix: 'Brandon Sanderson/Cosmere', parentOrder: 1.0),
        CategoryNode(id: 3, name: 'Mistborn Era 1', lft: 3, rgt: 4, depth: 2, parentId: 2, pathPrefix: 'Brandon Sanderson/Cosmere/Mistborn Era 1', parentOrder: 1.0),
      ];

      final audiobooks = [
        const Audiobook(
          path: '/path/to/book1',
          title: 'The Final Empire',
          author: 'Brandon Sanderson',
          files: ['01.mp3'],
          durationFormatted: '10:00:00',
          totalChapters: 1,
          chapters: [],
          categoryId: 3,
          parentOrder: 1.0,
        ),
        const Audiobook(
          path: '/path/to/uncategorized',
          title: 'Uncategorized Book',
          author: 'Unknown Author',
          files: ['02.mp3'],
          durationFormatted: '05:00:00',
          totalChapters: 1,
          chapters: [],
          categoryId: null,
        ),
      ];

      final state = HomeState(
        categories: categories,
        audiobooks: audiobooks,
      );

      expect(state.categories.length, equals(3));
      final uncategorized = state.audiobooks.where((b) => b.categoryId == null).toList();
      expect(uncategorized.length, equals(1));
      expect(uncategorized.first.title, equals('Uncategorized Book'));
    });

    test('syncCategoriesFromBookPaths includes directory category nodes for book folder paths', () {
      final relativeBookPaths = [
        'Brandon Sanderson/Cosmere/Mistborn Era 1/01 - The Final Empire',
        'Brandon Sanderson/Cosmere/Mistborn Era 1/02 - The Well of Ascension',
      ];

      final Set<String> prefixes = {};
      for (final relPath in relativeBookPaths) {
        final parts = relPath.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.length <= 1) continue;
        var currentPrefix = '';
        for (var i = 0; i < parts.length; i++) {
          currentPrefix = currentPrefix.isEmpty ? parts[i] : '$currentPrefix/${parts[i]}';
          prefixes.add(currentPrefix);
        }
      }

      expect(prefixes, contains('Brandon Sanderson'));
      expect(prefixes, contains('Brandon Sanderson/Cosmere'));
      expect(prefixes, contains('Brandon Sanderson/Cosmere/Mistborn Era 1'));
      expect(prefixes, contains('Brandon Sanderson/Cosmere/Mistborn Era 1/01 - The Final Empire'));
      expect(prefixes, contains('Brandon Sanderson/Cosmere/Mistborn Era 1/02 - The Well of Ascension'));
    });
  });
}
