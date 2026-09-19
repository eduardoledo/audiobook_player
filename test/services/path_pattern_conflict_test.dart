import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audiobook_player/models/path_pattern_rule.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ticket 01: PathPatternRule Conflict Validation Tests', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
      final db = await storage.database;
      await db.delete('settings');
      await db.delete('categories');
    });

    test('detects overlapping root path conflict when target path is a subpath of existing rule', () async {
      const existingRule = PathPatternRule(
        rootPath: '/library/audiobooks',
        roles: [PathSegmentRole.author, PathSegmentRole.saga, PathSegmentRole.bookTitle],
      );
      await storage.savePathPatternRule(existingRule);

      const newOverlappingRule = PathPatternRule(
        rootPath: '/library/audiobooks/Brandon Sanderson',
        roles: [PathSegmentRole.saga, PathSegmentRole.bookTitle],
      );

      final conflict = await storage.validatePathPatternConflict(newOverlappingRule);

      expect(conflict.hasConflict, isTrue);
      expect(conflict.conflictingRule?.rootPath, equals('/library/audiobooks'));
      expect(conflict.reason, contains('solapa'));
    });

    test('returns no conflict when root paths are independent and distinct', () async {
      const existingRule = PathPatternRule(
        rootPath: '/library/audiobooks',
        roles: [PathSegmentRole.author, PathSegmentRole.bookTitle],
      );
      await storage.savePathPatternRule(existingRule);

      const distinctRule = PathPatternRule(
        rootPath: '/other_library/podcasts',
        roles: [PathSegmentRole.author, PathSegmentRole.bookTitle],
      );

      final conflict = await storage.validatePathPatternConflict(distinctRule);

      expect(conflict.hasConflict, isFalse);
    });

    test('rebuildNestedSetFromPatterns populates category hierarchy and recalculates lft rgt bounds', () async {
      final tempDir = Directory('${Directory.current.path}/.scratch/test_nested_set');
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      final authorDir = Directory('${tempDir.path}/Brandon Sanderson');
      final sagaDir = Directory('${authorDir.path}/Mistborn');
      await sagaDir.create(recursive: true);

      final rule = PathPatternRule(
        rootPath: p.normalize(tempDir.path),
        roles: const [PathSegmentRole.author, PathSegmentRole.saga, PathSegmentRole.bookTitle],
      );

      await storage.savePathPatternRule(rule);

      final categories = await storage.getAllCategories();
      expect(categories.length, equals(2));

      final authorNode = categories.firstWhere((c) => c.name == 'Brandon Sanderson');
      final sagaNode = categories.firstWhere((c) => c.name == 'Mistborn');

      expect(authorNode.depth, equals(1));
      expect(sagaNode.depth, equals(2));
      expect(sagaNode.parentId, equals(authorNode.id));
      expect(authorNode.lft, equals(1));
      expect(sagaNode.lft, equals(2));
      expect(sagaNode.rgt, equals(3));
      expect(authorNode.rgt, equals(4));

      await tempDir.delete(recursive: true);
    });
  });
}

class SystemTempDirectory {
  static Future<Directory> create(String prefix) async {
    final sysTemp = Directory.systemTemp;
    final dir = Directory('${sysTemp.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}');
    return await dir.create(recursive: true);
  }
}

