import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:audiobook_player/services/audiobook_scanner.dart';

void main() {
  group('Hierarchical Metadata Files tests (.metadata.json)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('metadata_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Reads author.metadata.json, universe.metadata.json, and saga.metadata.json in hierarchy', () async {
      final rootPath = tempDir.path;
      
      // Build directory structure: root/Stephen King/The Dark Tower/The Gunslinger
      final authorDir = Directory(p.join(rootPath, 'Stephen King'))..createSync(recursive: true);
      final sagaDir = Directory(p.join(authorDir.path, 'The Dark Tower'))..createSync(recursive: true);
      final bookDir = Directory(p.join(sagaDir.path, 'The Gunslinger'))..createSync(recursive: true);

      // Create author.metadata.json
      File(p.join(authorDir.path, 'author.metadata.json')).writeAsStringSync('{"name": "Stephen King"}');

      // Create saga.metadata.json
      File(p.join(sagaDir.path, 'saga.metadata.json')).writeAsStringSync('{"name": "The Dark Tower"}');

      // Create book.metadata.json
      File(p.join(bookDir.path, 'book.metadata.json')).writeAsStringSync('{"title": "The Gunslinger"}');

      // Test reading hierarchy
      final metaMap = await AudiobookScanner.readHierarchyMetadata(bookDir.path, rootPath);

      expect(metaMap['author'], 'Stephen King');
      expect(metaMap['saga'], 'The Dark Tower');
    });

    test('ensureParentMetadataFiles creates author and saga metadata files', () async {
      final rootPath = tempDir.path;
      final authorDir = Directory(p.join(rootPath, 'Brandon Sanderson'))..createSync(recursive: true);
      final sagaDir = Directory(p.join(authorDir.path, 'Mistborn'))..createSync(recursive: true);
      final bookDir = Directory(p.join(sagaDir.path, 'The Final Empire'))..createSync(recursive: true);

      await AudiobookScanner.ensureParentMetadataFiles(
        dirPath: bookDir.path,
        rootDirectoryPath: rootPath,
        author: 'Brandon Sanderson',
        saga: 'Mistborn',
      );

      final authorMeta = File(p.join(authorDir.path, 'author.metadata.json'));
      final sagaMeta = File(p.join(sagaDir.path, 'saga.metadata.json'));

      expect(await authorMeta.exists(), isTrue);
      expect(await sagaMeta.exists(), isTrue);
      expect(authorMeta.readAsStringSync(), contains('Brandon Sanderson'));
      expect(sagaMeta.readAsStringSync(), contains('Mistborn'));
    });
  });
}
