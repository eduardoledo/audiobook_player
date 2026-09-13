import 'package:metadata_cli/path_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmere-style path parse', () {
    test('Author/Universe/Saga/Era/Book', () {
      final meta = parseDirPath(
        '/lib/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire',
        '/lib',
      );
      expect(meta, isNotNull);
      expect(meta!.author, 'Brandon Sanderson');
      expect(meta.universe, 'Cosmere');
      expect(meta.saga, 'Mistborn');
      expect(meta.sagaOrder, '02');
      expect(meta.universeOrder, '02');
      expect(meta.era, 'Era 1');
      expect(meta.bookTitle, 'The Final Empire');
      expect(meta.seriesPosition, '01');
      expect(meta.readingOrderKey, [2.0, 1.0, 1.0]);
    });

    test('standalone numbered book under universe', () {
      final meta = parseDirPath(
        '/lib/Brandon Sanderson/Cosmere/01 - Elantris',
        '/lib',
      );
      expect(meta!.universe, 'Cosmere');
      expect(meta.saga, isNull);
      expect(meta.bookTitle, 'Elantris');
      expect(meta.seriesPosition, '01');
      expect(meta.universeOrder, '01');
      expect(meta.readingOrderKey, [1.0]);
    });

    test('saga without era', () {
      final meta = parseDirPath(
        '/lib/Brandon Sanderson/Cosmere/05 - The Stormlight Archive/01 - The Way of Kings',
        '/lib',
      );
      expect(meta!.universe, 'Cosmere');
      expect(meta.saga, 'The Stormlight Archive');
      expect(meta.era, isNull);
      expect(meta.bookTitle, 'The Way of Kings');
      expect(meta.readingOrderKey, [5.0, 1.0]);
    });

    test('decimal book order inside era', () {
      final meta = parseDirPath(
        '/lib/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/0.5 - The Eleventh Metal',
        '/lib',
      );
      expect(meta!.seriesPosition, '0.5');
      expect(meta.readingOrderKey, [2.0, 1.0, 0.5]);
    });
  });

  group('reading order keys', () {
    test('expands saga before next universe sibling', () {
      final elantris = [1.0];
      final finalEmpire = [2.0, 1.0, 1.0];
      final alloy = [2.0, 2.0, 4.0];
      final warbreaker = [3.0];
      final keys = [warbreaker, alloy, elantris, finalEmpire]
        ..sort(compareReadingOrderKeys);
      expect(keys, [elantris, finalEmpire, alloy, warbreaker]);
    });
  });

  group('era vs disc parts', () {
    test('eras are not disc parts', () {
      expect(looksLikeEraFolder('Era 1'), isTrue);
      expect(looksLikeDiscPartFolder('Era 1'), isFalse);
      expect(looksLikeDiscPartFolder('CD1'), isTrue);
      expect(looksLikePartFolder('Era 1'), isTrue);
    });
  });

  group('tight hyphen prefixes (Eoin Colfer / Artemis Fowl)', () {
    test('orderToken and strip without space after hyphen', () {
      expect(orderTokenFromSegment('02-The Arctic Incident'), 2.0);
      expect(stripOrderPrefix('02-The Arctic Incident'), 'The Arctic Incident');
      expect(rawOrderPrefix('08-The Last Guardian'), '08');
      // Do not treat decimals as order-3 via the dot.
      expect(orderTokenFromSegment('3.14'), isNull);
      expect(orderTokenFromSegment('02 - Spaced'), 2.0);
    });

    test('Author/Series/01-Book (series as universe when book is numbered)', () {
      final meta = parseDirPath(
        '/lib/Eoin Colfer/Artemis Fowl/02-The Arctic Incident',
        '/lib',
      );
      expect(meta!.author, 'Eoin Colfer');
      // Same shape as Cosmere/01 - Elantris → unnumbered container is universe.
      expect(meta.universe, 'Artemis Fowl');
      expect(meta.saga, isNull);
      expect(meta.bookTitle, 'The Arctic Incident');
      expect(meta.seriesPosition, '02');
      expect(meta.universeOrder, '02');
      expect(meta.readingOrderKey, [2.0]);
    });
  });
}
