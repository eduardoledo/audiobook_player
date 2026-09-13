import 'package:metadata_cli/path_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('narratorFromPath', () {
    test('simple read by', () {
      expect(
        narratorFromPath(
          'The Mummy or Ramses the Damned - [1989] (read by Bob Askey)',
        ),
        'Bob Askey',
      );
      expect(
        narratorFromPath('1982 - The Master of Rampling Gate (read by Gigi Marceau)'),
        'Gigi Marceau',
      );
    });

    test('series-code prefix before read by', () {
      expect(
        narratorFromPath(
          '01 - Interview With the Vampire - [1976] (VC1 - read by Frank Muller)',
        ),
        'Frank Muller',
      );
      expect(
        narratorFromPath(
          "01 - The Claiming of Sleeping Beauty [1983] (B1 - read by George Holmes)",
        ),
        'George Holmes',
      );
      expect(
        narratorFromPath(
          '01- The Witching Hour [1990 ] (MW1 - read by Laura Giannarelli)',
        ),
        'Laura Giannarelli',
      );
      expect(
        narratorFromPath(
          '06 - Pandora [1998 (NV1 - read by Kate Reading)',
        ),
        'Kate Reading',
      );
    });

    test('other by-phrases', () {
      expect(narratorFromPath('Title (narrated by Jane Doe)'), 'Jane Doe');
      expect(narratorFromPath('Title (performed by A. Voice)'), 'A. Voice');
    });

    test('no narrator', () {
      expect(narratorFromPath('The Three-Body Problem (2014)'), isNull);
      expect(narratorFromPath('01 - Elantris'), isNull);
    });
  });

  group('stripNarratorFromTitle', () {
    test('removes narrator parens', () {
      expect(
        stripNarratorFromTitle(
          '01 - Interview With the Vampire (VC1 - read by Frank Muller)',
        ),
        '01 - Interview With the Vampire',
      );
      expect(
        stripNarratorFromTitle(
          'The Mummy or Ramses the Damned - [1989] (read by Bob Askey)',
        ),
        'The Mummy or Ramses the Damned - [1989]',
      );
    });
  });

  group('parseDirPath narrator', () {
    test('fills narrator, year, and cleans title', () {
      final meta = parseDirPath(
        '/lib/Anne Rice/Vampire Chronicles/01 - Interview With the Vampire - [1976] (VC1 - read by Frank Muller)',
        '/lib',
      );
      expect(meta, isNotNull);
      expect(meta!.publishYear, '1976');
      expect(meta.narrator, 'Frank Muller');
      expect(meta.seriesPosition, '01');
      expect(meta.bookTitle, 'Interview With the Vampire');
    });
  });
}
