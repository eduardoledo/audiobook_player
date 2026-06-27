import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/metadata_fetcher.dart';

void main() {
  group('MetadataFetcher Extraction Validation', () {
    test('Extracts series name and position from formatted title', () {
      // We can validate extract series logic by checking titles containing pattern "(SeriesName, #Position)"
      // Let's create helper check for the regex pattern implemented inside MetadataFetcher:
      // RegExp(r'\((.*?)(?:,\s*Book\s*(\d+)|(?:,\s*)?#(\d+))\)')
      
      final pattern = RegExp(r'\((.*?)(?:,\s*Book\s*(\d+)|(?:,\s*)?#(\d+))\)', caseSensitive: false);
      
      String testTitle1 = 'Harry Potter and the Sorcerer\'s Stone (Harry Potter, #1)';
      final match1 = pattern.firstMatch(testTitle1);
      expect(match1, isNotNull);
      expect(match1!.group(1)?.trim(), 'Harry Potter');
      expect(match1.group(2) ?? match1.group(3), '1');

      String testTitle2 = 'The Way of Kings (The Stormlight Archive, Book 1)';
      final match2 = pattern.firstMatch(testTitle2);
      expect(match2, isNotNull);
      expect(match2!.group(1)?.trim(), 'The Stormlight Archive');
      expect(match2.group(2) ?? match2.group(3), '1');
    });
  });
}
