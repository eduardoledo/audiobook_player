import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/path_metadata_parser.dart';

void main() {
  group('PathMetadataParser (Candidate 1 Seam)', () {
    test('parses default author/saga/title folder path', () {
      const parser = PathMetadataParser();
      final meta = parser.parsePath('Brandon Sanderson/Mistborn/The Final Empire');

      expect(meta.author, equals('Brandon Sanderson'));
      expect(meta.saga, equals('Mistborn'));
      expect(meta.bookTitle, equals('The Final Empire'));
    });

    test('parses manual user-configured segment mapping rules', () {
      const mapping = SegmentPathMapping(
        segmentRoles: [
          PathSegmentRole.author,
          PathSegmentRole.universe,
          PathSegmentRole.saga,
          PathSegmentRole.bookTitle,
        ],
      );
      const parser = PathMetadataParser(segmentMapping: mapping);
      final meta = parser.parsePath('Brandon Sanderson/Cosmere/Mistborn Era 1/01 - The Final Empire');

      expect(meta.author, equals('Brandon Sanderson'));
      expect(meta.universe, equals('Cosmere'));
      expect(meta.saga, equals('Mistborn Era 1'));
      expect(meta.bookTitle, equals('01 - The Final Empire'));
    });

    test('correctly identifies disc, part, and era folders', () {
      expect(PathMetadataParser.looksLikeEraFolder('Era 1'), isTrue);
      expect(PathMetadataParser.looksLikeDiscPartFolder('CD 01'), isTrue);
      expect(PathMetadataParser.looksLikeDiscPartFolder('Part 2'), isTrue);
      expect(PathMetadataParser.partOrderFromFolderName('Prologue'), equals(0));
      expect(PathMetadataParser.partOrderFromFolderName('Part 3'), equals(3));
    });
  });
}
