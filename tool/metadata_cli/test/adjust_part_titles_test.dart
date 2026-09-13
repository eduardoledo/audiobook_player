import 'package:metadata_cli/book_metadata.dart';
import 'package:metadata_cli/models.dart';
import 'package:test/test.dart';

void main() {
  group('adjustPartTitles', () {
    test('moves part-folder title into partName and uses parent as title', () {
      final meta = BookMetadata(
        title: 'CD1',
        author: 'Author',
        entryType: 'book',
      );
      meta.entryType = 'part';

      adjustPartTitles(
        meta,
        bookPath: '/library/Author/The Final Empire/CD1',
      );

      expect(meta.partName, 'CD1');
      expect(meta.partOf, 'The Final Empire');
      expect(meta.title, 'The Final Empire');
    });

    test('keeps a real book title and only fills part fields', () {
      final meta = BookMetadata(
        title: 'The Final Empire',
        author: 'Author',
        entryType: 'part',
      );

      adjustPartTitles(
        meta,
        bookPath: '/library/Author/The Final Empire/Disc 2',
      );

      expect(meta.title, 'The Final Empire');
      expect(meta.partName, 'Disc 2');
      expect(meta.partOf, 'The Final Empire');
    });
  });
}
