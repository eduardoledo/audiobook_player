import 'package:metadata_cli/models.dart';
import 'package:metadata_cli/saved_structure.dart';
import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/structure_match.dart';
import 'package:test/test.dart';

void main() {
  group('cutsFromSavedMetadata', () {
    test('builds ordered cuts from chapter timeline', () {
      final meta = BookMetadata(
        title: 'T',
        author: 'A',
        chapters: [
          {
            'index': 0,
            'title': 'Prologue',
            'start': 68.0,
            'end': 100.0,
          },
          {
            'index': 1,
            'title': 'Chapter 1',
            'part': 'Part One',
            'start': 100.0,
            'end': 200.0,
          },
        ],
      );
      final cuts = cutsFromSavedMetadata(meta);
      expect(cuts, isNotNull);
      expect(cuts!.length, 2);
      expect(cuts[0].epub.title, 'Prologue');
      expect(cuts[0].startSeconds, 68);
      expect(cuts[1].epub.part, 'Part One');
      expect(cuts[1].epub.chapterNumber, 1);
      expect(hasUsableSavedTimeline(meta), isTrue);
    });

    test('rejects missing times or overlaps', () {
      expect(
        cutsFromSavedMetadata(
          BookMetadata(
            title: 'T',
            author: 'A',
            chapters: [
              {'title': 'A', 'start': 0, 'end': 10},
            ],
          ),
        ),
        isNull,
      );
      expect(
        cutsFromSavedMetadata(
          BookMetadata(
            title: 'T',
            author: 'A',
            chapters: [
              {'title': 'A', 'start': 0, 'end': 10},
              {'title': 'B', 'start': 5, 'end': 20},
            ],
          ),
        ),
        isNull,
      );
      expect(
        cutsFromSavedMetadata(
          BookMetadata(
            title: 'T',
            author: 'A',
            chapters: [
              {'title': 'A'},
              {'title': 'B'},
            ],
          ),
        ),
        isNull,
      );
    });
  });

  group('enrichCutsWithEpubParts', () {
    test('copies part labels by chapter number', () {
      final meta = BookMetadata(
        title: 'T',
        author: 'A',
        chapters: [
          {'title': 'Chapter 1', 'start': 0.0, 'end': 10.0},
          {'title': 'Chapter 2', 'start': 10.0, 'end': 20.0},
        ],
      );
      final cuts = cutsFromSavedMetadata(meta)!;
      final epub = EpubStructure(
        epubPath: 'x.epub',
        entries: [
          const EpubTocEntry(
            title: 'Chapter 1',
            href: 'a',
            kind: EpubEntryKind.chapter,
            chapterNumber: 1,
            part: 'Part One',
            firstWords: '',
            firstWordsNormalized: [],
          ),
          const EpubTocEntry(
            title: 'Chapter 2',
            href: 'b',
            kind: EpubEntryKind.chapter,
            chapterNumber: 2,
            part: 'Part Two',
            firstWords: '',
            firstWordsNormalized: [],
          ),
        ],
      );
      final enriched = enrichCutsWithEpubParts(cuts: cuts, epub: epub);
      expect(enriched[0].epub.part, 'Part One');
      expect(enriched[1].epub.part, 'Part Two');
    });
  });

  group('alignSavedCutsToEpub', () {
    test('leaves gaps for resume', () {
      final saved = [
        AlignedChapterCut(
          epub: const EpubTocEntry(
            title: 'Prologue',
            href: '',
            kind: EpubEntryKind.prologue,
            firstWords: '',
            firstWordsNormalized: [],
          ),
          startSeconds: 10,
          endSeconds: 100,
        ),
        AlignedChapterCut(
          epub: const EpubTocEntry(
            title: 'Chapter 1',
            href: '',
            kind: EpubEntryKind.chapter,
            chapterNumber: 1,
            firstWords: '',
            firstWordsNormalized: [],
          ),
          startSeconds: 100,
          endSeconds: 200,
        ),
        AlignedChapterCut(
          epub: const EpubTocEntry(
            title: 'Chapter 3',
            href: '',
            kind: EpubEntryKind.chapter,
            chapterNumber: 3,
            firstWords: '',
            firstWordsNormalized: [],
          ),
          startSeconds: 300,
          endSeconds: 400,
        ),
      ];
      const epub = EpubStructure(
        epubPath: 'x.epub',
        entries: [
          EpubTocEntry(
            title: 'Prologue',
            href: 'a',
            kind: EpubEntryKind.prologue,
            firstWords: 'a b c d e f g h i j',
            firstWordsNormalized: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
          ),
          EpubTocEntry(
            title: 'Chapter 1',
            href: 'b',
            kind: EpubEntryKind.chapter,
            chapterNumber: 1,
            firstWords: 'a b c d e f g h i j',
            firstWordsNormalized: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
          ),
          EpubTocEntry(
            title: 'Chapter 2',
            href: 'c',
            kind: EpubEntryKind.chapter,
            chapterNumber: 2,
            firstWords: 'a b c d e f g h i j',
            firstWordsNormalized: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
          ),
          EpubTocEntry(
            title: 'Chapter 3',
            href: 'd',
            kind: EpubEntryKind.chapter,
            chapterNumber: 3,
            firstWords: 'a b c d e f g h i j',
            firstWordsNormalized: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
          ),
        ],
      );
      final aligned = alignSavedCutsToEpub(saved: saved, epub: epub);
      expect(countAlignedCuts(aligned), 3);
      expect(aligned[2], isNull); // Chapter 2 missing
      expect(aligned[3]!.startSeconds, 300);
      expect(alignedCoversAll(aligned), isFalse);
    });
  });
}
