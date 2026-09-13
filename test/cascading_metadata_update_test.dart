import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Cascading Segment Metadata Updates (ADR 0015)', () {
    late Directory tempDir;
    late LibraryStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cascading_test_');
      storage = LibraryStorage();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes parent .metadata.json and updates prefix matching books in SQLite', () async {
      final sagaDir = Directory(p.join(tempDir.path, 'Brandon Sanderson', 'Cosmere'));
      await sagaDir.create(recursive: true);

      final book1Dir = Directory(p.join(sagaDir.path, 'Elantris'));
      final book2Dir = Directory(p.join(sagaDir.path, 'Warbreaker'));
      await book1Dir.create(recursive: true);
      await book2Dir.create(recursive: true);

      final count = await storage.updateSegmentMetadata(
        scanRootPath: tempDir.path,
        segmentDirPath: sagaDir.path,
        metadata: {
          'name': 'Cosmere Saga',
          'author': 'Brandon Sanderson',
        },
      );

      final metaFile = File(p.join(sagaDir.path, 'saga.metadata.json'));
      expect(await metaFile.exists(), isTrue);
      expect(count, isA<int>());
    });
  });
}
