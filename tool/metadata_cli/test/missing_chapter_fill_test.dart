import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/missing_chapter_fill.dart';
import 'package:test/test.dart';

void main() {
  group('planMissingChapterGaps', () {
    test('points each gap at the previous present chapter file', () {
      const epub = EpubStructure(
        epubPath: 'x.epub',
        entries: [
          EpubTocEntry(
            title: 'Prologue',
            href: 'a',
            kind: EpubEntryKind.prologue,
            firstWords: 'a b c d e f g h i j',
            firstWordsNormalized: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
            wordCount: 100,
          ),
          EpubTocEntry(
            title: 'Chapter 1',
            href: 'b',
            kind: EpubEntryKind.chapter,
            chapterNumber: 1,
            firstWords: 'k l m n o p q r s t',
            firstWordsNormalized: ['k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't'],
            wordCount: 200,
          ),
          EpubTocEntry(
            title: 'Chapter 2',
            href: 'c',
            kind: EpubEntryKind.chapter,
            chapterNumber: 2,
            firstWords: 'u v w x y z a b c d',
            firstWordsNormalized: ['u', 'v', 'w', 'x', 'y', 'z', 'a', 'b', 'c', 'd'],
            wordCount: 200,
          ),
          EpubTocEntry(
            title: 'Chapter 3',
            href: 'd',
            kind: EpubEntryKind.chapter,
            chapterNumber: 3,
            firstWords: 'e f g h i j k l m n',
            firstWordsNormalized: ['e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'],
            wordCount: 200,
          ),
        ],
      );

      // Missing chapter 2 → should search inside chapter 1's file.
      final gaps = planMissingChapterGaps(
        epub: epub,
        audioFiles: [
          '/book/01 - Prologue.m4b',
          '/book/02 - Chapter 1.m4b',
          '/book/03 - Chapter 3.m4b',
        ],
        bookPath: '/book',
      );

      expect(gaps.length, 1);
      expect(gaps.first.missing.title, 'Chapter 2');
      expect(gaps.first.previous.title, 'Chapter 1');
      expect(gaps.first.previousAudioPath, '/book/02 - Chapter 1.m4b');
    });
  });
}
