import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/crashlytics_service.dart';
import 'package:audiobook_player/models/category_node.dart';

void main() {
  group('CrashlyticsService Unit Tests', () {
    test('computes category_hierarchy_path from CategoryNode ancestors correctly', () {
      final categories = [
        const CategoryNode(id: 1, name: 'Brandon Sanderson', lft: 1, rgt: 6, depth: 1, pathPrefix: 'Brandon Sanderson'),
        const CategoryNode(id: 2, name: 'Cosmere', lft: 2, rgt: 5, depth: 2, parentId: 1, pathPrefix: 'Brandon Sanderson/Cosmere'),
        const CategoryNode(id: 3, name: 'Mistborn', lft: 3, rgt: 4, depth: 3, parentId: 2, pathPrefix: 'Brandon Sanderson/Cosmere/Mistborn'),
      ];

      final result = CrashlyticsService.computeCategoryHierarchyPath(
        bookCategoryId: 3,
        allCategories: categories,
      );

      expect(result, equals('Brandon Sanderson > Cosmere > Mistborn'));
    });

    test('returns empty string when bookCategoryId is null or not found in categories', () {
      final result = CrashlyticsService.computeCategoryHierarchyPath(
        bookCategoryId: null,
        allCategories: [],
      );

      expect(result, isEmpty);
    });
  });
}
