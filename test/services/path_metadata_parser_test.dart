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

    test('parses 2-segment standalone path (Author/BookTitle) assigning saga == null and universe == null', () {
      const parser = PathMetadataParser();
      final meta = parser.parsePath('Stephen King/The Shining');

      expect(meta.author, equals('Stephen King'));
      expect(meta.universe, isNull);
      expect(meta.saga, isNull);
      expect(meta.bookTitle, equals('The Shining'));
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

    test('extracts publication year and narrator from path strings and sanitizes title', () {
      expect(PathMetadataParser.publishYearFromPath('The Final Empire (2006)'), equals('2006'));
      expect(PathMetadataParser.publishYearFromPath('1973 - The Hobbit'), equals('1973'));
      expect(PathMetadataParser.narratorFromPath('The Hobbit (read by Frank Muller)'), equals('Frank Muller'));

      const parser = PathMetadataParser();
      final meta = parser.parsePath('Brandon Sanderson/Mistborn (2006)/01 - The Final Empire (2006) (read by Michael Kramer)');

      expect(meta.publishYear, equals('2006'));
      expect(meta.narrator, equals('Michael Kramer'));
      expect(meta.bookTitle, equals('The Final Empire'));
      expect(meta.saga, equals('Mistborn'));
    });

    test('deduplicates hierarchy levels when lower segment matches parent level name', () {
      const parser = PathMetadataParser();
      final meta = parser.parsePath('Brandon Sanderson/Cosmere/Cosmere/The Final Empire');

      expect(meta.author, equals('Brandon Sanderson'));
      expect(meta.universe, equals('Cosmere'));
      expect(meta.saga, isNull);
      expect(meta.bookTitle, equals('The Final Empire'));
    });
  });
}
