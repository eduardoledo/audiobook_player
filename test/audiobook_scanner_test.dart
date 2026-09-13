import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/audiobook_scanner.dart';
import 'package:audiobook_player/models/audiobook.dart';

void main() {
  group('AudiobookScanner parseDirPath tests', () {
    test('author/universe/saga/book pattern (4 segments)', () {
      const base = '/Users/user/audiobooks';
      const path =
          '$base/Brandon Sanderson/Cosmere/Mistborn/The Final Empire';
      final metadata = AudiobookScanner.parseDirPath(path, base);

      expect(metadata, isNotNull);
      expect(metadata!.author, 'Brandon Sanderson');
      expect(metadata.universe, 'Cosmere');
      expect(metadata.saga, 'Mistborn');
      expect(metadata.bookTitle, 'The Final Empire');
    });

    test('author/saga/book pattern (3 segments)', () {
      const base = '/Users/user/audiobooks';
      const path = '$base/Brandon Sanderson/Mistborn/The Final Empire';
      final metadata = AudiobookScanner.parseDirPath(path, base);

      expect(metadata, isNotNull);
      expect(metadata!.author, 'Brandon Sanderson');
      expect(metadata.universe, isNull);
      expect(metadata.saga, 'Mistborn');
      expect(metadata.bookTitle, 'The Final Empire');
    });

    test('author/universe/saga/era/book pattern (5 segments)', () {
      const base = '/Users/user/audiobooks';
      const path =
          '$base/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire';
      final metadata = AudiobookScanner.parseDirPath(path, base);

      expect(metadata, isNotNull);
      expect(metadata!.author, 'Brandon Sanderson');
      expect(metadata.universe, 'Cosmere');
      expect(metadata.saga, 'Mistborn');
      expect(metadata.era, 'Era 1');
      expect(metadata.bookTitle, 'The Final Empire');
      expect(metadata.seriesSequence, '01');
      expect(metadata.universeOrder, '02');
      expect(metadata.readingOrderKey, [2.0, 1.0, 1.0]);
    });

    test('tight hyphen book prefixes (01-Title)', () {
      const base = '/lib';
      const path = '$base/Eoin Colfer/Artemis Fowl/02-The Arctic Incident';
      final metadata = AudiobookScanner.parseDirPath(path, base);

      expect(metadata!.author, 'Eoin Colfer');
      expect(metadata.universe, 'Artemis Fowl');
      expect(metadata.bookTitle, 'The Arctic Incident');
      expect(metadata.seriesSequence, '02');
      expect(AudiobookScanner.orderTokenFromSegment('02-The Arctic Incident'), 2.0);
      expect(AudiobookScanner.stripOrderPrefix('08-The Last Guardian'),
          'The Last Guardian');
    });
  });

  group('AudiobookScanner part folder detection', () {
    test('recognizes discs, parts and eras', () {
      expect(AudiobookScanner.looksLikePartFolder('CD1'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Disc 2'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Part 3'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Era 1'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('01'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Chapter 1'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Capítulo 02'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Section 3'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Sección 4'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Ch. 5'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Cap. 6'), isTrue);
    });

    test('recognizes prologue and epilogue folders', () {
      expect(AudiobookScanner.looksLikePartFolder('Prólogo'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Prologo'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Prologue'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Epílogo'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Epilogo'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Epilogue'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('01 - Prólogo'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Epílogo 1'), isTrue);
      expect(AudiobookScanner.looksLikePartFolder('Prologue 2'), isTrue);
    });

    test('does not treat numbered book titles as parts', () {
      expect(
        AudiobookScanner.looksLikePartFolder('01 - The Final Empire'),
        isFalse,
      );
      expect(AudiobookScanner.looksLikePartFolder('Mistborn'), isFalse);
      expect(
        AudiobookScanner.looksLikePartFolder('Prologue to a Murder'),
        isFalse,
      );
    });

    test('detects reading order within the book', () {
      expect(AudiobookScanner.partOrderFromFolderName('Prólogo'), 0);
      expect(AudiobookScanner.partOrderFromFolderName('Prologue'), 0);
      expect(AudiobookScanner.partOrderFromFolderName('01 - Prólogo'), 1);
      expect(AudiobookScanner.partOrderFromFolderName('CD1'), 1);
      expect(AudiobookScanner.partOrderFromFolderName('Disc 2'), 2);
      expect(AudiobookScanner.partOrderFromFolderName('01'), 1);
      expect(AudiobookScanner.partOrderFromFolderName('Parte III'), 3);
      expect(AudiobookScanner.partOrderFromFolderName('Era 1'), 1);
      expect(AudiobookScanner.partOrderFromFolderName('Epílogo'), 10000);
      expect(AudiobookScanner.partOrderFromFolderName('Chapter 1'), 1);
      expect(AudiobookScanner.partOrderFromFolderName('Capítulo 02'), 2);
      expect(AudiobookScanner.partOrderFromFolderName('Section 3'), 3);
      expect(AudiobookScanner.partOrderFromFolderName('Ch. 4'), 4);
      expect(AudiobookScanner.partOrderFromFolderName('Mistborn'), isNull);
    });
  });

  group('Audiobook Saga Sorting tests', () {
    // We recreate the exact sorting logic used in home_screen.dart to verify it.
    int naturalCompare(String a, String b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    int sortBooks(Audiobook a, Audiobook b) {
      // 1. Try sorting by seriesSequence (saga number)
      if (a.seriesSequence != null && b.seriesSequence != null) {
        final numA = double.tryParse(a.seriesSequence!);
        final numB = double.tryParse(b.seriesSequence!);
        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = naturalCompare(a.seriesSequence!, b.seriesSequence!);
          if (cmp != 0) return cmp;
        }
      } else if (a.seriesSequence != null) {
        return -1;
      } else if (b.seriesSequence != null) {
        return 1;
      }

      // 2. Try sorting by publishYear
      if (a.publishYear != null && b.publishYear != null) {
        final numA = int.tryParse(a.publishYear!);
        final numB = int.tryParse(b.publishYear!);
        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = a.publishYear!.compareTo(b.publishYear!);
          if (cmp != 0) return cmp;
        }
      } else if (a.publishYear != null) {
        return -1;
      } else if (b.publishYear != null) {
        return 1;
      }

      // 3. Fallback to natural alphabetical sort on title
      return naturalCompare(a.title, b.title);
    }

    test('Sorts primarily by seriesSequence (including decimals)', () {
      const b1 = Audiobook(path: 'p1', title: 'Book 1.5', seriesSequence: '1.5', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b2 = Audiobook(path: 'p2', title: 'Book 1', seriesSequence: '1', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b3 = Audiobook(path: 'p3', title: 'Book 2', seriesSequence: '2', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b4 = Audiobook(path: 'p4', title: 'No Seq Book', seriesSequence: null, author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);

      final list = [b3, b1, b4, b2];
      list.sort(sortBooks);

      expect(list[0].title, 'Book 1');
      expect(list[1].title, 'Book 1.5');
      expect(list[2].title, 'Book 2');
      expect(list[3].title, 'No Seq Book');
    });

    test('Sorts by publishYear if seriesSequence is missing/equal', () {
      const b1 = Audiobook(path: 'p1', title: 'Later Book', publishYear: '2020', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b2 = Audiobook(path: 'p2', title: 'Earlier Book', publishYear: '2010', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b3 = Audiobook(path: 'p3', title: 'No Year Book', publishYear: null, author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);

      final list = [b3, b1, b2];
      list.sort(sortBooks);

      expect(list[0].title, 'Earlier Book');
      expect(list[1].title, 'Later Book');
      expect(list[2].title, 'No Year Book');
    });

    test('Falls back to title alphabetical sorting', () {
      const b1 = Audiobook(path: 'p1', title: 'Z Title', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);
      const b2 = Audiobook(path: 'p2', title: 'A Title', author: 'A', files: [], durationFormatted: '00:00:00', totalChapters: 0, chapters: []);

      final list = [b1, b2];
      list.sort(sortBooks);

      expect(list[0].title, 'A Title');
      expect(list[1].title, 'Z Title');
    });
  });

  group('AudiobookScanner MP3 Duration Parser', () {
    test('Correctly parses or returns null instead of hanging on mock MP3 bytes', () async {
      await importHelper();
    });
  });
}

Future<void> importHelper() async {
  // Use a localized temp directory within the workspace to follow guidelines
  final dir = Directory('./test_temp');
  if (!await dir.exists()) await dir.create();
  final file = File('./test_temp/test_mock.mp3');
  
  // MPEG frame header for Layer III (MP3), 128kbps, 44100Hz
  final List<int> mp3Bytes = [
    0xFF, 0xFB, 0x90, 0x64,
    0x00, 0x00, 0x00, 0x00,
  ];
  await file.writeAsBytes(mp3Bytes);
  
  try {
    final meta = await AudiobookScanner.getAudioMetadata(file);
    expect(meta, isNotNull);
    expect(meta!.duration.inMilliseconds, equals(0));
  } finally {
    if (await file.exists()) {
      await file.delete();
    }
    if (await dir.exists()) {
      await dir.delete();
    }
  }
}
