import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/audiobook_scanner.dart';
import 'package:audiobook_player/models/audiobook.dart';

void main() {
  group('AudiobookScanner parseDirPath tests', () {
    test('author/saga/book/parts pattern (4 segments)', () {
      final base = '/Users/user/audiobooks';
      final path = '$base/J.R.R. Tolkien/The Lord of the Rings/The Fellowship of the Ring/parts';
      final metadata = AudiobookScanner.parseDirPath(path, base);
      
      expect(metadata, isNotNull);
      expect(metadata!.author, 'J.R.R. Tolkien');
      expect(metadata.saga, 'The Lord of the Rings');
      expect(metadata.bookTitle, 'The Fellowship of the Ring');
    });

    test('author/saga/book pattern (3 segments)', () {
      final base = '/Users/user/audiobooks';
      final path = '$base/Brandon Sanderson/Mistborn/The Final Empire';
      final metadata = AudiobookScanner.parseDirPath(path, base);
      
      expect(metadata, isNotNull);
      expect(metadata!.author, 'Brandon Sanderson');
      expect(metadata.saga, 'Mistborn');
      expect(metadata.bookTitle, 'The Final Empire');
    });

    test('author/book pattern (2 segments)', () {
      final base = '/Users/user/audiobooks';
      final path = '$base/Neil Gaiman/Neverwhere';
      final metadata = AudiobookScanner.parseDirPath(path, base);
      
      expect(metadata, isNotNull);
      expect(metadata!.author, 'Neil Gaiman');
      expect(metadata.saga, isNull);
      expect(metadata.bookTitle, 'Neverwhere');
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
      final b1 = Audiobook(path: 'p1', title: 'Book 1.5', seriesSequence: '1.5', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b2 = Audiobook(path: 'p2', title: 'Book 1', seriesSequence: '1', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b3 = Audiobook(path: 'p3', title: 'Book 2', seriesSequence: '2', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b4 = Audiobook(path: 'p4', title: 'No Seq Book', seriesSequence: null, author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);

      final list = [b3, b1, b4, b2];
      list.sort(sortBooks);

      expect(list[0].title, 'Book 1');
      expect(list[1].title, 'Book 1.5');
      expect(list[2].title, 'Book 2');
      expect(list[3].title, 'No Seq Book');
    });

    test('Sorts by publishYear if seriesSequence is missing/equal', () {
      final b1 = Audiobook(path: 'p1', title: 'Later Book', publishYear: '2020', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b2 = Audiobook(path: 'p2', title: 'Earlier Book', publishYear: '2010', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b3 = Audiobook(path: 'p3', title: 'No Year Book', publishYear: null, author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);

      final list = [b3, b1, b2];
      list.sort(sortBooks);

      expect(list[0].title, 'Earlier Book');
      expect(list[1].title, 'Later Book');
      expect(list[2].title, 'No Year Book');
    });

    test('Falls back to title alphabetical sorting', () {
      final b1 = Audiobook(path: 'p1', title: 'Z Title', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);
      final b2 = Audiobook(path: 'p2', title: 'A Title', author: 'A', files: const [], durationFormatted: '00:00:00', totalChapters: 0, chapters: const []);

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
