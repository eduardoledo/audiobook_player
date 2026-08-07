import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/path_pattern_rule.dart';
import 'package:audiobook_player/services/audiobook_scanner.dart';

void main() {
  group('Custom PathPatternRule parsing tests', () {
    test('Applies custom roles (Author / Saga / Book)', () {
      final base = '/audiobooks';
      final path = '$base/Anne Rice/Vampire Chronicles/Interview With the Vampire';

      final rule = PathPatternRule(
        rootPath: base,
        roles: const [
          PathSegmentRole.author,
          PathSegmentRole.saga,
          PathSegmentRole.bookTitle,
        ],
      );

      final metadata = AudiobookScanner.parseDirPath(path, base, customRule: rule);

      expect(metadata, isNotNull);
      expect(metadata!.author, 'Anne Rice');
      expect(metadata.saga, 'Vampire Chronicles');
      expect(metadata.bookTitle, 'Interview With the Vampire');
    });

    test('Applies custom roles with Universe and Ignore', () {
      final base = '/audiobooks';
      final path = '$base/Brandon Sanderson/Cosmere/Mistborn/The Final Empire/ExtraFolder';

      final rule = PathPatternRule(
        rootPath: base,
        roles: const [
          PathSegmentRole.author,
          PathSegmentRole.universe,
          PathSegmentRole.saga,
          PathSegmentRole.bookTitle,
          PathSegmentRole.ignore,
        ],
      );

      final metadata = AudiobookScanner.parseDirPath(path, base, customRule: rule);

      expect(metadata, isNotNull);
      expect(metadata!.author, 'Brandon Sanderson');
      expect(metadata.universe, 'Cosmere');
      expect(metadata.saga, 'Mistborn');
      expect(metadata.bookTitle, 'The Final Empire');
    });
  });
}
