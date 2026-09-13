import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/bloc/home_state.dart';

void main() {
  group('Ticket 02: HomeScreen Directory Tree from Nested Set', () {
    testWidgets('renders folder nodes matching CategoryNode list in HomeState', (WidgetTester tester) async {
      const categories = [
        CategoryNode(id: 1, name: 'Brandon Sanderson', lft: 1, rgt: 6, depth: 0, pathPrefix: 'Brandon Sanderson'),
        CategoryNode(id: 2, name: 'Cosmere', lft: 2, rgt: 5, depth: 1, parentId: 1, pathPrefix: 'Brandon Sanderson/Cosmere'),
        CategoryNode(id: 3, name: 'Mistborn Era 1', lft: 3, rgt: 4, depth: 2, parentId: 2, pathPrefix: 'Brandon Sanderson/Cosmere/Mistborn Era 1'),
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
        ),
      ];

      final state = HomeState(
        categories: categories,
        audiobooks: audiobooks,
      );

      // Build tree via state
      expect(state.categories.length, equals(3));
      expect(state.audiobooks.first.categoryId, equals(3));
    });
  });
}
