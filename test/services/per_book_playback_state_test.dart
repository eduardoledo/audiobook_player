import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiobook_player/models/book_playback_state.dart';
import 'package:audiobook_player/services/library_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Per-Book Isolated Playback State', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
    });

    test('saves and restores distinct playback states per book path independently', () async {
      const bookAPath = '/storage/audiobooks/BookA';
      const bookBPath = '/storage/audiobooks/BookB';

      final stateA = const BookPlaybackState(
        bookPath: bookAPath,
        positionMs: 120000,
        chapterIndex: 2,
        playbackSpeed: 1.25,
        volumeGain: 1.5,
      );

      final stateB = const BookPlaybackState(
        bookPath: bookBPath,
        positionMs: 450000,
        chapterIndex: 5,
        playbackSpeed: 2.0,
        volumeGain: 0.8,
      );

      await storage.saveBookPlaybackState(stateA);
      await storage.saveBookPlaybackState(stateB);

      final restoredA = await storage.getBookPlaybackState(bookAPath);
      final restoredB = await storage.getBookPlaybackState(bookBPath);

      expect(restoredA.playbackSpeed, equals(1.25));
      expect(restoredA.positionMs, equals(120000));
      expect(restoredA.volumeGain, equals(1.5));

      expect(restoredB.playbackSpeed, equals(2.0));
      expect(restoredB.positionMs, equals(450000));
      expect(restoredB.volumeGain, equals(0.8));
    });
  });
}
