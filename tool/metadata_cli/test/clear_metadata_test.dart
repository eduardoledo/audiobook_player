import 'dart:io';

import 'package:metadata_cli/book_metadata.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('metadata_clear_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> touch(String relative) async {
    final file = File(p.join(tmp.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString('{}\n');
    return file;
  }

  test('findLibraryMetadataFiles finds sidecars and skips audio', () async {
    await touch('Author/author.metadata.json');
    await touch('Author/Saga/saga.metadata.json');
    await touch('Author/Saga/Book/book.metadata.json');
    await touch('Author/Saga/Book/metadata.json');
    await touch('Author/Saga/Book/cover.jpg');
    await touch('Author/Saga/Book/chapter01.mp3');

    final withoutCovers = await findLibraryMetadataFiles(tmp.path);
    expect(withoutCovers.map((f) => p.basename(f.path)).toSet(), {
      'author.metadata.json',
      'saga.metadata.json',
      'book.metadata.json',
      'metadata.json',
    });

    final withCovers = await findLibraryMetadataFiles(
      tmp.path,
      includeCovers: true,
    );
    expect(withCovers.any((f) => p.basename(f.path) == 'cover.jpg'), isTrue);
  });

  test('clearLibraryMetadata deletes only metadata files', () async {
    final bookMeta = await touch('Book/book.metadata.json');
    final audio = await touch('Book/a.mp3');
    final cover = await touch('Book/cover.jpg');

    final deleted = await clearLibraryMetadata(tmp.path);
    expect(deleted, [bookMeta.path]);
    expect(await bookMeta.exists(), isFalse);
    expect(await audio.exists(), isTrue);
    expect(await cover.exists(), isTrue);

    await touch('Book/book.metadata.json');
    final deleted2 = await clearLibraryMetadata(
      tmp.path,
      includeCovers: true,
    );
    expect(deleted2.length, 2);
    expect(await cover.exists(), isFalse);
  });
}
