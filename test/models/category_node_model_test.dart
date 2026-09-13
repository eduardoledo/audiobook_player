import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/models/audiobook.dart';

void main() {
  group('Ticket 01: CategoryNode & Audiobook Model Tests', () {
    test('CategoryNode serializes and deserializes correctly', () {
      const node = CategoryNode(
        id: 1,
        name: 'Cosmere',
        lft: 1,
        rgt: 10,
        depth: 0,
        parentId: null,
        pathPrefix: 'Brandon Sanderson/Cosmere',
      );

      final map = node.toMap();
      expect(map['id'], equals(1));
      expect(map['name'], equals('Cosmere'));
      expect(map['lft'], equals(1));
      expect(map['rgt'], equals(10));
      expect(map['depth'], equals(0));
      expect(map['parent_id'], isNull);
      expect(map['path_prefix'], equals('Brandon Sanderson/Cosmere'));

      final restored = CategoryNode.fromMap(map);
      expect(restored.id, equals(1));
      expect(restored.name, equals('Cosmere'));
      expect(restored.lft, equals(1));
      expect(restored.rgt, equals(10));
      expect(restored.depth, equals(0));
      expect(restored.parentId, isNull);
      expect(restored.pathPrefix, equals('Brandon Sanderson/Cosmere'));
    });

    test('Audiobook serializes and deserializes categoryId', () {
      final json = {
        'title': 'The Final Empire',
        'author': 'Brandon Sanderson',
        'files': ['01.mp3'],
        'durationFormatted': '10:00:00',
        'totalChapters': 1,
        'chapters': <Map<String, dynamic>>[],
        'categoryId': 42,
      };

      final book = Audiobook.fromJson(json, '/path/to/book');
      expect(book.categoryId, equals(42));

      final serialized = book.toJson();
      expect(serialized['categoryId'], equals(42));
    });
  });
}
