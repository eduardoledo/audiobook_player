import 'package:metadata_cli/path_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('publishYearFromPath', () {
    test('brackets with optional spaces', () {
      expect(publishYearFromPath('Title [1976]'), '1976');
      expect(publishYearFromPath('Title [1990 ]'), '1990');
      expect(publishYearFromPath('Title - [1989] (read by X)'), '1989');
    });

    test('parentheses year alone', () {
      expect(publishYearFromPath('The Three-Body Problem (2014)'), '2014');
      expect(publishYearFromPath('00 - Ball Lightning (2018)'), '2018');
    });

    test('leading year prefix', () {
      expect(publishYearFromPath('1973 - The Matlock Paper'), '1973');
      expect(publishYearFromPath('2021 - Project Hail Mary (Sci-Fi)'), '2021');
    });

    test('author.year in brackets', () {
      expect(
        publishYearFromPath('Dexter 01 - Darkly Dreaming Dexter [Jeff Lindsay.2004]'),
        '2004',
      );
    });

    test('unclosed bracket before paren', () {
      expect(
        publishYearFromPath('06 - Pandora [1998 (NV1 - read by Kate Reading)'),
        '1998',
      );
    });

    test('ignores years inside narrator parens', () {
      expect(
        publishYearFromPath('Title (VC1 - read by Frank Muller)'),
        isNull,
      );
    });
  });

  group('stripPublishYearFromTitle', () {
    test('cleans common wrappers', () {
      expect(
        stripPublishYearFromTitle(
          '01 - Interview With the Vampire - [1976] (VC1 - read by Frank Muller)',
        ),
        '01 - Interview With the Vampire (VC1 - read by Frank Muller)',
      );
      expect(
        stripPublishYearFromTitle('1973 - The Matlock Paper'),
        'The Matlock Paper',
      );
      expect(
        stripPublishYearFromTitle('The Three-Body Problem (2014)'),
        'The Three-Body Problem',
      );
    });
  });

  group('parseDirPath year', () {
    test('fills publishYear and cleans title', () {
      final meta = parseDirPath(
        '/lib/Anne Rice/Vampire Chronicles/01 - Interview With the Vampire - [1976] (VC1 - read by Frank Muller)',
        '/lib',
      );
      expect(meta, isNotNull);
      expect(meta!.publishYear, '1976');
      expect(meta.seriesPosition, '01');
      expect(meta.bookTitle, 'Interview With the Vampire');
      expect(meta.bookTitle, isNot(contains('1976')));
      expect(meta.bookTitle, isNot(contains('Frank Muller')));
    });
  });
}
