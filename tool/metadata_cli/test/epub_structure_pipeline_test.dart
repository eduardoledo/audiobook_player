import 'dart:io';

import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/structure_match.dart';
import 'package:metadata_cli/embedded_chapters.dart';
import 'package:metadata_cli/audio_split.dart';
import 'package:metadata_cli/proximity_windows.dart';
import 'package:test/test.dart';

void main() {
  final bookDir =
      '/home/eduardo/Descargas/Books/Audiobooks/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire';
  final epubPath = '$bookDir/The Final Empire by Brandon Sanderson.epub';

  group('epub_structure Final Empire', () {
    test('parses TOC and opening phrases', () {
      if (!File(epubPath).existsSync()) {
        // Skip when library path is unavailable in CI.
        return;
      }
      final epub = parseEpubStructure(epubPath);
      expect(epub.entries.length, 40);
      expect(epub.entries.first.kind, EpubEntryKind.prologue);
      expect(epub.entries.first.title, 'Prologue');
      expect(epub.entries.first.firstWordsNormalized.length, greaterThanOrEqualTo(8));
      expect(
        epub.entries.first.firstWordsNormalized.take(4).join(' '),
        'ash fell from the',
      );
      expect(epub.entries[1].title, 'Chapter 1');
      expect(epub.entries.last.kind, EpubEntryKind.epilogue);
      // Parts assigned from spine PART ONE… headings.
      expect(epub.entries[1].part, isNotNull);
      expect(epub.entries.first.wordCount, greaterThan(100));
    });

    test('firstNarrativeWords skips boilerplate', () {
      const html = '''
<html><body>
<style>@page { margin: 5pt; }</style>
<p>Brandon Sanderson - Mistborn 1 - The Final Empire</p>
<p>PROLOGUE</p>
<p>Ash fell from the sky. Lord Tresting frowned, watching</p>
</body></html>
''';
      final phrase = firstNarrativeWords(html, wordCount: 10);
      expect(phrase.normalized.take(4).toList(), ['ash', 'fell', 'from', 'the']);
      expect(phrase.normalized.length, greaterThanOrEqualTo(8));
    });
  });

  group('structure_match', () {
    test('rejects count mismatch (22 vs 40)', () {
      if (!File(epubPath).existsSync()) return;
      final epub = parseEpubStructure(epubPath);
      final embedded = List.generate(
        22,
        (i) => EmbeddedChapter(
          title: '${(i + 1).toString().padLeft(2, '0')} The Final Empire',
          startSeconds: i * 1000.0,
          endSeconds: (i + 1) * 1000.0,
        ),
      );
      final match = matchEmbeddedToEpub(epub: epub, embedded: embedded);
      expect(match.matched, isFalse);
      expect(match.reason, contains('Count mismatch'));
    });

    test('accepts aligned titles', () {
      final epub = EpubStructure(
        epubPath: 'x.epub',
        entries: [
          EpubTocEntry(
            title: 'Prologue',
            href: 'a',
            kind: EpubEntryKind.prologue,
            firstWords: 'once upon a time there was a king who',
            firstWordsNormalized: 'once upon a time there was a king who'.split(' '),
          ),
          EpubTocEntry(
            title: 'Chapter 1',
            href: 'b',
            kind: EpubEntryKind.chapter,
            chapterNumber: 1,
            firstWords: 'the morning sun rose over the quiet valley',
            firstWordsNormalized:
                'the morning sun rose over the quiet valley'.split(' '),
          ),
        ],
      );
      final embedded = [
        const EmbeddedChapter(
          title: 'Prologue',
          startSeconds: 0,
          endSeconds: 100,
        ),
        const EmbeddedChapter(
          title: 'Chapter 1',
          startSeconds: 100,
          endSeconds: 200,
        ),
      ];
      final match = matchEmbeddedToEpub(epub: epub, embedded: embedded);
      expect(match.matched, isTrue);
      expect(match.cuts.first.epub.title, 'Prologue');
      expect(match.cuts.first.startSeconds, 0);
    });
  });

  group('audio_split naming', () {
    test('includes part in basename', () {
      final cut = AlignedChapterCut(
        epub: EpubTocEntry(
          title: 'Chapter 1',
          href: 'a',
          kind: EpubEntryKind.chapter,
          chapterNumber: 1,
          part: 'Part 1',
          firstWords: 'a b c d e f g h i j',
          firstWordsNormalized: 'a b c d e f g h i j'.split(' '),
        ),
        startSeconds: 0,
        endSeconds: 10,
      );
      expect(chapterOutputBasename(cut), 'Part 1 - Chapter 1');
      expect(
        chapterOutputBasename(
          AlignedChapterCut(
            epub: EpubTocEntry(
              title: 'Prologue',
              href: 'a',
              kind: EpubEntryKind.prologue,
              firstWords: 'a b c d e f g h i j',
              firstWordsNormalized: 'a b c d e f g h i j'.split(' '),
            ),
            startSeconds: 0,
            endSeconds: 10,
          ),
        ),
        'Prologue',
      );
    });

    test('detects duplicate output basenames', () {
      AlignedChapterCut cut(String title, {String? part}) => AlignedChapterCut(
            epub: EpubTocEntry(
              title: title,
              href: 'a',
              kind: EpubEntryKind.chapter,
              part: part,
              firstWords: 'a b c d e f g h i j',
              firstWordsNormalized: 'a b c d e f g h i j'.split(' '),
            ),
            startSeconds: 0,
            endSeconds: 10,
          );

      expect(
        duplicateChapterBasenames([
          cut('Chapter 1', part: 'Part 1'),
          cut('Chapter 1', part: 'Part 2'),
        ]),
        isEmpty,
      );
      expect(
        duplicateChapterBasenames([
          cut('Chapter 1'),
          cut('chapter 1'),
        ]),
        isNotEmpty,
      );
      expect(
        () => ensureUniqueChapterBasenames([
          cut('Intro'),
          cut('Intro'),
        ]),
        throwsStateError,
      );
    });
  });

  group('phrase helpers', () {
    test('exact and progressive containment', () {
      const needle = [
        'ash',
        'fell',
        'from',
        'the',
        'sky',
        'lord',
        'tresting',
        'frowned',
        'watching',
        'the',
      ];
      expect(
        phraseContainedExact(
          'Ash fell from the sky. Lord Tresting frowned, watching the fields',
          needle,
        ),
        isTrue,
      );
      expect(
        progressiveWordMatchCount(
          'Ash fell from the sky Lord Tresting',
          needle,
        ),
        7,
      );
      expect(
        phraseContainedFuzzy(
          'Ash fell from the sky Lord Tresting frowned watching',
          needle,
        ),
        isTrue, // 9/10 soft
      );
    });

    test('tolerates ASR mishear tresting→trusting', () {
      const needle = [
        'ash',
        'fell',
        'from',
        'the',
        'sky',
        'lord',
        'tresting',
        'frowned',
        'glancing',
        'up',
      ];
      expect(wordsFuzzyEqual('tresting', 'trusting'), isTrue);
      expect(wordEditDistance('tresting', 'trusting'), 1);
      final depth = progressiveWordMatchCount(
        'One. Ash fell from the sky. Lord trusting frowned, glancing up at the ready midday skies',
        needle,
      );
      expect(depth, 10);
      expect(phraseContainedExact(
        'Ash fell from the sky. Lord trusting frowned, glancing up',
        needle,
      ), isTrue);
    });

    test('tolerates Whisper garble of Mistborn chapter 1 opening', () {
      const needle = [
        'ash',
        'fell',
        'from',
        'the',
        'sky',
        'vin',
        'watched',
        'the',
        'downy',
        'flakes',
      ];
      // Whisper tiny: "Ash fell" → "I shall fell", "Vin watched" → "Then watch"
      expect(wordsFuzzyEqual('watch', 'watched'), isTrue);
      final depth = progressiveWordMatchCount(
        'I shall fell from the sky. Then watch the downy flakes drift through the air.',
        needle,
      );
      expect(depth, greaterThanOrEqualTo(9));
    });
  });

  group('proximity windows', () {
    test('subset proximity uses totalBookWords scaling', () {
      final entries = [
        EpubTocEntry(
          title: 'Prologue',
          href: 'a',
          kind: EpubEntryKind.prologue,
          firstWords: 'a b c d e f g h i j',
          firstWordsNormalized: 'a b c d e f g h i j'.split(' '),
          wordCount: 5000,
        ),
        EpubTocEntry(
          title: 'Chapter 1',
          href: 'b',
          kind: EpubEntryKind.chapter,
          chapterNumber: 1,
          firstWords: 'k l m n o p q r s t',
          firstWordsNormalized: 'k l m n o p q r s t'.split(' '),
          wordCount: 3000,
        ),
      ];
      final wrong = buildProximityWindows(
        entries: entries,
        durationSeconds: 100000,
      );
      // Without totalBookWords, chapter 1 is stretched far into the file.
      expect(wrong[1].expectedStart, closeTo(62500, 1));

      final right = buildProximityWindows(
        entries: entries,
        durationSeconds: 100000,
        totalBookWords: 200000,
      );
      expect(right[1].expectedStart, closeTo(2500, 1));
    });

    test('scales search by chapter and part word counts', () {
      final entries = [
        EpubTocEntry(
          title: 'Prologue',
          href: 'a',
          kind: EpubEntryKind.prologue,
          part: 'Part 1',
          firstWords: 'a b c d e f g h i j',
          firstWordsNormalized: 'a b c d e f g h i j'.split(' '),
          wordCount: 1000,
        ),
        EpubTocEntry(
          title: 'Chapter 1',
          href: 'b',
          kind: EpubEntryKind.chapter,
          chapterNumber: 1,
          part: 'Part 1',
          firstWords: 'k l m n o p q r s t',
          firstWordsNormalized: 'k l m n o p q r s t'.split(' '),
          wordCount: 3000,
        ),
        EpubTocEntry(
          title: 'Chapter 2',
          href: 'c',
          kind: EpubEntryKind.chapter,
          chapterNumber: 2,
          part: 'Part 2',
          firstWords: 'u v w x y z a b c d',
          firstWordsNormalized: 'u v w x y z a b c d'.split(' '),
          wordCount: 6000,
        ),
      ];
      final wins = buildProximityWindows(
        entries: entries,
        durationSeconds: 10000,
      );
      expect(wins.length, 3);
      expect(wins[0].expectedStart, 0);
      expect(wins[1].expectedStart, closeTo(1000, 1)); // 1000/10000 * 10000
      expect(wins[2].expectedDuration, greaterThan(wins[1].expectedDuration));
      expect(wins[2].searchWidth, greaterThan(wins[0].searchWidth));

      final cands = candidatesInProximity(
        silenceCandidates: [500, 1100, 5000],
        window: wins[1],
        minStart: 0,
      );
      expect(cands, isNotEmpty);
      // Nearest to expected (~1000) first among silence hits.
      expect(cands.first, anyOf(1000, 1100, closeTo(wins[1].expectedStart, 1)));

      final coarse = sampleProximityTimes(
        window: wins[1],
        minStart: 0,
        stepSeconds: 75,
      );
      expect(coarse.length, lessThan(cands.length));
      expect(coarse.first, closeTo(wins[1].expectedStart, 1));
    });
  });
}
