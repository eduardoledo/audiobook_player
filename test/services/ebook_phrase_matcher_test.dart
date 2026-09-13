import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/keyword_chapter_matcher.dart';

void main() {
  group('Ebook Phrase Matcher & Chapter Verification (Ticket 08)', () {
    test('matches audio opening phrase to corresponding eBook section title', () {
      final sectionTitles = ['Prologue', 'Chapter 1: The Final Empire', 'Chapter 2: Ash Fell'];
      const audioPhrase = 'Chapter One: The Final Empire';

      final match = KeywordChapterMatcher.matchChapterTitle(
        phrase: audioPhrase,
        knownTitles: sectionTitles,
      );

      expect(match, equals('Chapter 1: The Final Empire'));
    });
  });
}
