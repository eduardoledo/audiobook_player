import 'package:audiobook_player/bloc/home_cubit.dart';
import 'package:audiobook_player/bloc/home_state.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/models/bookmark.dart';
import 'package:audiobook_player/screens/player_screen.dart';
import 'package:audiobook_player/services/audio_player_service.dart';
import 'package:audiobook_player/services/audiobook_scanner.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audio_meta/audio_meta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_audio_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Ticket 01: PlayerScreen + AudioPlayerService + SQLite FFI Seam', () {
    late LibraryStorage storage;
    late FakeAudioEngine engine;
    late AudioPlayerService playerService;
    late HomeCubit homeCubit;

    Audiobook buildBook(String bookPath) {
      return Audiobook(
        path: bookPath,
        title: 'The Final Empire',
        author: 'Brandon Sanderson',
        hasMetadataLocally: true,
        files: [
          '$bookPath/01 - Prologue.mp3',
          '$bookPath/02 - Chapter One.mp3',
        ],
        durationFormatted: '01:30:00',
        totalChapters: 2,
        chapters: const [
          Chapter(
            index: 0,
            start: 0,
            end: 1800,
            duration: 1800,
            startFormatted: '00:00:00',
            endFormatted: '00:30:00',
            durationFormatted: '00:30:00',
            title: 'Prologue',
            displayTitle: 'Prologue',
          ),
          Chapter(
            index: 1,
            start: 1800,
            end: 5400,
            duration: 3600,
            startFormatted: '00:30:00',
            endFormatted: '01:30:00',
            durationFormatted: '01:00:00',
            title: 'Chapter One',
            displayTitle: 'Chapter One',
          ),
        ],
      );
    }

    tearDown(() async {
      await homeCubit.close();
      playerService.dispose();
    });

    testWidgets(
      'mounts PlayerScreen with injected dependencies and initializes audiobook playlist on AudioEngine',
      (tester) async {
        final bookPath =
            '/books/mistborn_${DateTime.now().microsecondsSinceEpoch}';
        final book = buildBook(bookPath);

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 60),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('The Final Empire'), findsWidgets);
        expect(find.text('Brandon Sanderson'), findsOneWidget);
        expect(find.text('Prologue'), findsOneWidget);
        expect(engine.loadedTracks.length, equals(2));
        expect(engine.loadedTracks.first.filePath, equals(book.files[0]));
        expect(engine.currentIndex, equals(0));
      },
    );

    testWidgets(
      'drives playback state, position updates, and chapter seeking deterministically without platform channels',
      (tester) async {
        final bookPath =
            '/books/mistborn_playback_${DateTime.now().microsecondsSinceEpoch}';
        final book = buildBook(bookPath);

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 60),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();

        expect(playerService.playing, isTrue);
        expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

        engine.emitPosition(const Duration(minutes: 4, seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('04:15'), findsOneWidget);

        await tester.ensureVisible(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        expect(engine.currentIndex, equals(1));
        expect(engine.position, equals(Duration.zero));
      },
    );

    testWidgets(
      'creates, persists, and lists a Bookmark end-to-end through PlayerScreen and SQLite FFI storage',
      (tester) async {
        final bookPath =
            '/books/mistborn_bookmark_${DateTime.now().microsecondsSinceEpoch}';
        final book = buildBook(bookPath);

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 60),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        engine.emitPosition(const Duration(minutes: 2, seconds: 5));
        await tester.pump();

        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Kelsier arrives');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Remount PlayerScreen against the same SQLite FFI storage to verify persistence via UI seam
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('remounted_player'),
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final bookmarkTile = find.widgetWithText(ListTile, 'Kelsier arrives');
        expect(bookmarkTile, findsOneWidget);
        expect(
          find.descendant(
            of: bookmarkTile,
            matching: find.textContaining('02:05'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'calculates missing chapter durations on PlayerScreen open via injected metadata probe without filesystem I/O',
      (tester) async {
        final bookPath =
            '/books/uncalculated_${DateTime.now().microsecondsSinceEpoch}';
        final uncalculatedBook = Audiobook(
          path: bookPath,
          title: 'Warbreaker',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$bookPath/01.mp3',
            '$bookPath/02.mp3',
          ],
          durationFormatted: '00:00:00',
          totalChapters: 2,
          chapters: const [],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            uncalculatedBook.files[0]: const Duration(minutes: 20),
            uncalculatedBook.files[1]: const Duration(minutes: 40),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [uncalculatedBook]),
          audioMetadataProbe: (path) async {
            final dur = engine.trackDurationsByPath[path] ?? Duration.zero;
            return AudioFileMetadata(
              duration: dur,
              bitRate: 128000,
              sampleRate: 44100,
              channelCount: 2,
              type: AudioType.mp3,
              title: path.endsWith('01.mp3') ? 'Prologue' : 'Chapter 1',
            );
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: uncalculatedBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(homeCubit.state.audiobooks.first.chapters.length, equals(2));
        expect(homeCubit.state.audiobooks.first.chapters[0].duration, equals(1200.0));
        expect(homeCubit.state.audiobooks.first.chapters[1].duration, equals(2400.0));
        expect(engine.loadedTracks.length, equals(2));
      },
    );
  });

  group('Ticket 02: Total-Book Bookmark Creation, Seeking & List Formatting', () {
    late LibraryStorage storage;
    late FakeAudioEngine engine;
    late AudioPlayerService playerService;
    late HomeCubit homeCubit;

    tearDown(() async {
      await homeCubit.close();
      playerService.dispose();
    });

    testWidgets(
      'saves cumulative global position_ms across chapters, sorts chronologically, and formats >= 1h subtitles with Bookmark N fallback',
      (tester) async {
        final bookPath =
            '/books/mistborn_t02_sort_${DateTime.now().microsecondsSinceEpoch}';
        final book = Audiobook(
          path: bookPath,
          title: 'The Final Empire',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$bookPath/01 - Prologue.mp3',
            '$bookPath/02 - Chapter One.mp3',
          ],
          durationFormatted: '01:30:00',
          totalChapters: 2,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 1800,
              duration: 1800,
              startFormatted: '00:00:00',
              endFormatted: '00:30:00',
              durationFormatted: '00:30:00',
              title: 'Prologue',
              displayTitle: 'Prologue',
            ),
            Chapter(
              index: 1,
              start: 1800,
              end: 5400,
              duration: 3600,
              startFormatted: '00:30:00',
              endFormatted: '01:30:00',
              durationFormatted: '01:00:00',
              title: 'Chapter One',
              displayTitle: 'Part One - Chapter One',
              part: 'Part One',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 60),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          // 1-to-1 multi-file chapters derive per-file durations directly from chapters without probing disk
          fileDurationProbe: (_) =>
              Future<Duration?>.error(StateError('unexpected disk probe')),
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Jump to Chapter 2 (index 1) at local 02:00 -> global 00:32:00 (1,920,000 ms)
        await tester.ensureVisible(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        engine.emitPosition(const Duration(minutes: 2));
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Skaa rebellion');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // 2. Return to Chapter 1 (index 0) at local 05:12 -> global 00:05:12 (312,000 ms), empty note
        await tester.ensureVisible(find.byTooltip('Previous chapter'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Previous chapter'));
        await tester.pumpAndSettle();
        engine.emitPosition(const Duration(minutes: 5, seconds: 12));
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // 3. Open Bookmarks tab and verify chronological order + >= 1h formatting
        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final firstTile = find.widgetWithText(ListTile, 'Bookmark 1');
        final secondTile = find.widgetWithText(ListTile, 'Skaa rebellion');
        expect(firstTile, findsOneWidget);
        expect(secondTile, findsOneWidget);
        expect(
          tester.getTopLeft(firstTile).dy,
          lessThan(tester.getTopLeft(secondTile).dy),
        );
        expect(
          find.descendant(
            of: firstTile,
            matching: find.text('00:05:12 / 01:30:00 (6%) • Prologue'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: secondTile,
            matching: find.text('00:32:00 / 01:30:00 (36%) • Chapter One'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ensures chapter durations are calculated when adding a Bookmark on an uncalculated Audiobook so preceding chapters are never zero',
      (tester) async {
        final bookPath =
            '/books/uncalc_bookmark_${DateTime.now().microsecondsSinceEpoch}';
        final uncalculatedBook = Audiobook(
          path: bookPath,
          title: 'Elantris',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$bookPath/01.mp3',
            '$bookPath/02.mp3',
          ],
          durationFormatted: '00:00:00',
          totalChapters: 2,
          chapters: const [],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            uncalculatedBook.files[0]: const Duration(minutes: 20),
            uncalculatedBook.files[1]: const Duration(minutes: 40),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        // HomeState starts empty (e.g., book opened before library state sync)
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: const HomeState(),
          audioMetadataProbe: (path) async {
            final dur = engine.trackDurationsByPath[path] ?? Duration.zero;
            return AudioFileMetadata(
              duration: dur,
              bitRate: 128000,
              sampleRate: 44100,
              channelCount: 2,
              type: AudioType.mp3,
              title: path.endsWith('01.mp3') ? 'Prologue' : 'Chapter 1',
            );
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: uncalculatedBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to second file (index 1) at local 02:00 -> global 00:22:00 (1,320,000 ms)
        await engine.seek(const Duration(minutes: 2), index: 1);
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Midway');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(ListTile, 'Midway');
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('00:22:00 / 01:00:00 (37%) • Chapter 1'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping a Bookmark seeks across files/chapters, preserves play/pause state, and skips 1s resume rewind on next Play from pause',
      (tester) async {
        final bookPath =
            '/books/mistborn_t02_seek_${DateTime.now().microsecondsSinceEpoch}';
        final book = Audiobook(
          path: bookPath,
          title: 'The Well of Ascension',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$bookPath/01 - Prologue.mp3',
            '$bookPath/02 - Chapter One.mp3',
          ],
          durationFormatted: '01:30:00',
          totalChapters: 2,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 1800,
              duration: 1800,
              startFormatted: '00:00:00',
              endFormatted: '00:30:00',
              durationFormatted: '00:30:00',
              title: 'Prologue',
              displayTitle: 'Prologue',
            ),
            Chapter(
              index: 1,
              start: 1800,
              end: 5400,
              duration: 3600,
              startFormatted: '00:30:00',
              endFormatted: '01:30:00',
              durationFormatted: '01:00:00',
              title: 'Chapter One',
              displayTitle: 'Chapter One',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        // Pre-existing SQLite bookmark rows (inserted out of chronological order)
        await storage.addBookmark(
          Bookmark(
            bookPath: book.path,
            positionMs: 2100000, // 00:35:00 global -> file 1, local 05:00
            label: 'Plot twist',
          ),
        );
        await storage.addBookmark(
          Bookmark(
            bookPath: book.path,
            positionMs: 300000, // 00:05:00 global -> file 0, local 05:00
            label: 'Early clue',
          ),
        );

        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 60),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start playing in Chapter 0
        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        expect(playerService.playing, isTrue);
        expect(engine.currentIndex, equals(0));

        // Open Chapters/Bookmarks list and switch to Bookmarks tab
        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        // Tap 'Plot twist' (global 00:35:00) while PLAYING -> jumps to file 1 @ 05:00, stays playing
        final plotTwistTile = find.widgetWithText(ListTile, 'Plot twist');
        await tester.ensureVisible(plotTwistTile);
        await tester.pumpAndSettle();
        await tester.tap(plotTwistTile);
        await tester.pumpAndSettle();

        expect(engine.currentIndex, equals(1));
        expect(engine.position, equals(const Duration(minutes: 5)));
        expect(playerService.playing, isTrue);

        // Pause playback, then tap 'Early clue' (global 00:05:00) while PAUSED
        await tester.ensureVisible(find.byIcon(Icons.pause_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.pause_circle_filled));
        await tester.pumpAndSettle();
        expect(playerService.playing, isFalse);

        final earlyClueTile = find.widgetWithText(ListTile, 'Early clue');
        await tester.ensureVisible(earlyClueTile);
        await tester.pumpAndSettle();
        await tester.tap(earlyClueTile);
        await tester.pumpAndSettle();

        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(const Duration(minutes: 5)));
        expect(playerService.playing, isFalse);

        // Press Play from pause after tapping Bookmark -> starts at exact 05:00 (no 1s rewind)
        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();

        expect(playerService.playing, isTrue);
        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(const Duration(minutes: 5)));
      },
    );

    testWidgets(
      'formats < 1h single-file .m4b bookmarks as MM:SS, keeps timestamps invariant across Playback Speed changes, and seeks embedded chapters accurately',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bookPath =
            '/books/emperors_soul_${DateTime.now().microsecondsSinceEpoch}';
        final m4bBook = Audiobook(
          path: bookPath,
          title: "The Emperor's Soul",
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: ['$bookPath/emperors_soul.m4b'],
          durationFormatted: '00:45:00',
          totalChapters: 2,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 1200,
              duration: 1200,
              startFormatted: '00:00:00',
              endFormatted: '00:20:00',
              durationFormatted: '00:20:00',
              title: 'Day One',
              displayTitle: 'Day One',
            ),
            Chapter(
              index: 1,
              start: 1200,
              end: 2700,
              duration: 1500,
              startFormatted: '00:20:00',
              endFormatted: '00:45:00',
              durationFormatted: '00:25:00',
              title: 'Day Two',
              displayTitle: 'Day Two',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            m4bBook.files[0]: const Duration(minutes: 45),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [m4bBook]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: m4bBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change Playback Speed to 2.0x via UI
        await tester.tap(find.text('1.0x'));
        await tester.pumpAndSettle();
        final twoXOption = find.widgetWithText(ListTile, '2.0x');
        await tester.ensureVisible(twoXOption);
        await tester.pumpAndSettle();
        await tester.tap(twoXOption);
        await tester.pumpAndSettle();
        expect(playerService.speed, equals(2.0));

        // Jump to embedded Chapter 2 ('Day Two', start: 20:00) via Next chapter button
        await tester.ensureVisible(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next chapter'));
        await tester.pumpAndSettle();
        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(const Duration(minutes: 20)));

        // Advance to 25:12 (1,512,000 ms) inside 'Day Two' and add bookmark
        engine.emitPosition(const Duration(minutes: 25, seconds: 12));
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Soulstamp forged');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        // Verify < 1h MM:SS formatting (no 00: prefix) and 1.0x invariance at 2.0x speed
        final bookmarkTile = find.widgetWithText(ListTile, 'Soulstamp forged');
        expect(bookmarkTile, findsOneWidget);
        expect(
          find.descendant(
            of: bookmarkTile,
            matching: find.text('25:12 / 45:00 (56%) • Day Two'),
          ),
          findsOneWidget,
        );

        // Switch speed to 1.5x and confirm bookmark subtitle remains identical
        await playerService.setSpeed(1.5);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: bookmarkTile,
            matching: find.text('25:12 / 45:00 (56%) • Day Two'),
          ),
          findsOneWidget,
        );

        // Rewind to 01:00 while paused, tap bookmark, then press Play -> exact 25:12
        engine.emitPosition(const Duration(minutes: 1));
        await tester.pump();
        await tester.ensureVisible(bookmarkTile);
        await tester.pumpAndSettle();
        await tester.tap(bookmarkTile);
        await tester.pumpAndSettle();

        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(const Duration(minutes: 25, seconds: 12)));
        expect(playerService.playing, isFalse);

        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();

        expect(playerService.playing, isTrue);
        expect(engine.position, equals(const Duration(minutes: 25, seconds: 12)));
      },
    );
  });

  group('Ticket 03: AI-Detected Multi-File Chapters & Metadata Edge Cases', () {
    late LibraryStorage storage;
    late FakeAudioEngine engine;
    late AudioPlayerService playerService;
    late HomeCubit homeCubit;

    tearDown(() async {
      await homeCubit.close();
      playerService.dispose();
    });

    testWidgets(
      'maps global position_ms <-> (fileIndex, localOffset) via cached file durations and resolves AI-detected logical chapters (including exact end-of-book)',
      (tester) async {
        final bookPath =
            '/books/wor_ai_chapters_${DateTime.now().microsecondsSinceEpoch}';
        // 2 physical files (30m + 45m = 75m), 4 AI-detected logical chapters
        final book = Audiobook(
          path: bookPath,
          title: 'Words of Radiance',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$bookPath/part1.mp3', // 30:00 (1800s)
            '$bookPath/part2.mp3', // 45:00 (2700s)
          ],
          durationFormatted: '01:15:00',
          totalChapters: 4,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 900,
              duration: 900,
              startFormatted: '00:00:00',
              endFormatted: '00:15:00',
              durationFormatted: '00:15:00',
              title: 'Prologue: To Weep',
              displayTitle: 'Prologue: To Weep',
            ),
            Chapter(
              index: 1,
              start: 900,
              end: 2400,
              duration: 1500,
              startFormatted: '00:15:00',
              endFormatted: '00:40:00',
              durationFormatted: '00:25:00',
              title: 'Chapter 1: Winds and Oaths',
              displayTitle: 'Chapter 1: Winds and Oaths',
            ),
            Chapter(
              index: 2,
              start: 2400,
              end: 3600,
              duration: 1200,
              startFormatted: '00:40:00',
              endFormatted: '01:00:00',
              durationFormatted: '00:20:00',
              title: 'Chapter 2: Honor Is Dead',
              displayTitle: 'Chapter 2: Honor Is Dead',
            ),
            Chapter(
              index: 3,
              start: 3600,
              end: 4500,
              duration: 900,
              startFormatted: '01:00:00',
              endFormatted: '01:15:00',
              durationFormatted: '00:15:00',
              title: 'Epilogue: Wit',
              displayTitle: 'Epilogue: Wit',
            ),
          ],
        );

        var allowDiskProbe = true;
        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        engine = FakeAudioEngine(
          trackDurationsByPath: {
            book.files[0]: const Duration(minutes: 30),
            book.files[1]: const Duration(minutes: 45),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async =>
              allowDiskProbe ? engine.trackDurationsByPath[path] : null,
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [book]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: book,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Physical file 1 (starts at 30:00) + local 05:00 = global 00:35:00 (2,100,000 ms)
        // Falls inside AI Chapter 1 [00:15:00..00:40:00)
        await engine.seek(const Duration(minutes: 5), index: 1);
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Bridge Four salute');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Physical file 1 + local 45:00 = exact book endpoint 01:15:00 (4,500,000 ms)
        // Clamps to final chapter 'Epilogue: Wit'
        await engine.seek(const Duration(minutes: 45), index: 1);
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Final line');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final bridgeTile = find.widgetWithText(ListTile, 'Bridge Four salute');
        final finalTile = find.widgetWithText(ListTile, 'Final line');
        expect(bridgeTile, findsOneWidget);
        expect(finalTile, findsOneWidget);
        expect(
          find.descendant(
            of: bridgeTile,
            matching: find.text(
              '00:35:00 / 01:15:00 (47%) • Chapter 1: Winds and Oaths',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: finalTile,
            matching: find.text('01:15:00 / 01:15:00 (100%) • Epilogue: Wit'),
          ),
          findsOneWidget,
        );

        // Disable further probing; cached per-file durations still resolve cross-file seek accurately
        allowDiskProbe = false;
        await engine.seek(const Duration(minutes: 1), index: 0);
        await tester.pump();

        await tester.ensureVisible(bridgeTile);
        await tester.pumpAndSettle();
        await tester.tap(bridgeTile);
        await tester.pumpAndSettle();

        expect(engine.currentIndex, equals(1));
        expect(engine.position, equals(const Duration(minutes: 5)));
      },
    );

    testWidgets(
      'omits total duration and chapter suffix cleanly on 0-duration empty-chapter books without throwing on tap',
      (tester) async {
        final emptyBookPath =
            '/books/empty_meta_${DateTime.now().microsecondsSinceEpoch}';
        final emptyBook = Audiobook(
          path: emptyBookPath,
          title: 'Unreadable Archive',
          author: 'Unknown',
          hasMetadataLocally: true,
          files: const [],
          durationFormatted: '00:00:00',
          totalChapters: 0,
          chapters: const [],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        await storage.addBookmark(
          Bookmark(
            bookPath: emptyBook.path,
            positionMs: 0,
            label: 'Origin',
          ),
        );
        await storage.addBookmark(
          Bookmark(
            bookPath: emptyBook.path,
            positionMs: 195000, // 03:15
            label: 'Mystery spot',
          ),
        );

        engine = FakeAudioEngine();
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (_) async => null,
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [emptyBook]),
          audioMetadataProbe: (_) async => null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: emptyBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final originTile = find.widgetWithText(ListTile, 'Origin');
        final mysteryTile = find.widgetWithText(ListTile, 'Mystery spot');
        expect(
          find.descendant(of: originTile, matching: find.text('00:00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: mysteryTile, matching: find.text('03:15')),
          findsOneWidget,
        );

        await tester.tap(mysteryTile);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'clamps negative, zero, and out-of-range bookmark seeks safely within physical file bounds',
      (tester) async {
        final clampBookPath =
            '/books/clamp_book_${DateTime.now().microsecondsSinceEpoch}';
        final clampBook = Audiobook(
          path: clampBookPath,
          title: 'Shadows for Silence',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: [
            '$clampBookPath/01.mp3', // 20:00
            '$clampBookPath/02.mp3', // 25:00
          ],
          durationFormatted: '00:00:00',
          totalChapters: 1,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 0,
              duration: 0,
              startFormatted: '00:00:00',
              endFormatted: '00:00:00',
              durationFormatted: '00:00:00',
              title: 'Corrupt Header',
              displayTitle: 'Corrupt Header',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        await storage.addBookmark(
          Bookmark(
            bookPath: clampBook.path,
            positionMs: -5000,
            label: 'Negative legacy',
          ),
        );
        await storage.addBookmark(
          Bookmark(
            bookPath: clampBook.path,
            positionMs: 0,
            label: 'Zero start',
          ),
        );
        await storage.addBookmark(
          Bookmark(
            bookPath: clampBook.path,
            positionMs: 9999999, // Exceeds 45:00 (2,700,000 ms)
            label: 'Past the end',
          ),
        );

        engine = FakeAudioEngine(
          trackDurationsByPath: {
            clampBook.files[0]: const Duration(minutes: 20),
            clampBook.files[1]: const Duration(minutes: 25),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [clampBook]),
          audioMetadataProbe: (_) async => const AudioFileMetadata(
            duration: Duration.zero,
            bitRate: 0,
            sampleRate: 0,
            channelCount: 0,
            type: AudioType.mp3,
            title: 'Corrupt Header',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: clampBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final negTile = find.widgetWithText(ListTile, 'Negative legacy');
        final zeroTile = find.widgetWithText(ListTile, 'Zero start');
        final pastEndTile = find.widgetWithText(ListTile, 'Past the end');

        // 0-total omits '/ 00:00 (0%)' and negative position clamps cleanly to 00:00
        expect(
          find.descendant(
            of: negTile,
            matching: find.text('00:00 • Corrupt Header'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: zeroTile,
            matching: find.text('00:00 • Corrupt Header'),
          ),
          findsOneWidget,
        );

        // Seeking to 9,999,999 ms clamps safely to final file (index 1) at its 25:00 end
        await tester.ensureVisible(pastEndTile);
        await tester.pumpAndSettle();
        await tester.tap(pastEndTile);
        await tester.pumpAndSettle();
        expect(engine.currentIndex, equals(1));
        expect(engine.position, equals(const Duration(minutes: 25)));

        // Seeking to 0 ms and -5000 ms clamps safely to first file (index 0) at 00:00
        await tester.ensureVisible(zeroTile);
        await tester.pumpAndSettle();
        await tester.tap(zeroTile);
        await tester.pumpAndSettle();
        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(Duration.zero));

        await tester.ensureVisible(negTile);
        await tester.pumpAndSettle();
        await tester.tap(negTile);
        await tester.pumpAndSettle();
        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(Duration.zero));
      },
    );

    testWidgets(
      'preserves 1s resume rewind on subsequent pause->play after seeking a Bookmark while playing, lands on file 0 when all multi-file durations are 0, and uses full book end when first AI chapter starts after 0:00',
      (tester) async {
        // 1. AI-detected single-file book where Chapter 1 starts at 02:00 (120s) and ends at 01:00:00 (3600s)
        // Sum of chapter durations is 58:00, but actual book end is 01:00:00 (>= 1h -> HH:MM:SS).
        final aiIntroPath =
            '/books/ai_intro_${DateTime.now().microsecondsSinceEpoch}';
        final aiIntroBook = Audiobook(
          path: aiIntroPath,
          title: 'Oathbringer',
          author: 'Brandon Sanderson',
          hasMetadataLocally: true,
          files: ['$aiIntroPath/oathbringer.m4b'],
          durationFormatted: '01:00:00',
          totalChapters: 1,
          chapters: const [
            Chapter(
              index: 0,
              start: 120,
              end: 3600,
              duration: 3480,
              startFormatted: '00:02:00',
              endFormatted: '01:00:00',
              durationFormatted: '00:58:00',
              title: 'Chapter 1',
              displayTitle: 'Chapter 1',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        await storage.addBookmark(
          Bookmark(
            bookPath: aiIntroBook.path,
            positionMs: 300000, // 00:05:00
            label: 'Intro Done',
          ),
        );

        engine = FakeAudioEngine(
          trackDurationsByPath: {
            aiIntroBook.files[0]: const Duration(hours: 1),
          },
        );
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (path) async => engine.trackDurationsByPath[path],
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [aiIntroBook]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: aiIntroBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start playing, open Bookmarks, tap 'Intro Done' while PLAYING
        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final introTile = find.widgetWithText(ListTile, 'Intro Done');
        // Total book duration must be 01:00:00 (from chapters.last.end), NOT 58:00
        expect(
          find.descendant(
            of: introTile,
            matching: find.text('00:05:00 / 01:00:00 (8%) • Chapter 1'),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(introTile);
        await tester.pumpAndSettle();
        await tester.tap(introTile);
        await tester.pumpAndSettle();
        expect(playerService.playing, isTrue);
        expect(engine.position, equals(const Duration(minutes: 5)));

        // Advance to 06:00, pause, and press Play -> MUST apply 1s resume rewind to 05:59 (ADR 0002)
        engine.emitPosition(const Duration(minutes: 6));
        await tester.pump();

        await tester.ensureVisible(find.byIcon(Icons.pause_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.pause_circle_filled));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();
        expect(
          engine.position,
          equals(const Duration(minutes: 5, seconds: 59)),
        );
      },
    );

    testWidgets(
      'lands on file 0 (not the last file) when seeking a 0 ms Bookmark on a multi-file Audiobook whose durations are all 0',
      (tester) async {
        final zeroMultiPath =
            '/books/zero_multi_${DateTime.now().microsecondsSinceEpoch}';
        final zeroMultiBook = Audiobook(
          path: zeroMultiPath,
          title: 'Unknown Tapes',
          author: 'Unknown',
          hasMetadataLocally: true,
          files: [
            '$zeroMultiPath/tape1.mp3',
            '$zeroMultiPath/tape2.mp3',
          ],
          durationFormatted: '00:00:00',
          totalChapters: 2,
          chapters: const [
            Chapter(
              index: 0,
              start: 0,
              end: 0,
              duration: 0,
              startFormatted: '00:00:00',
              endFormatted: '00:00:00',
              durationFormatted: '00:00:00',
              title: 'Tape 1',
              displayTitle: 'Tape 1',
            ),
            Chapter(
              index: 1,
              start: 0,
              end: 0,
              duration: 0,
              startFormatted: '00:00:00',
              endFormatted: '00:00:00',
              durationFormatted: '00:00:00',
              title: 'Tape 2',
              displayTitle: 'Tape 2',
            ),
          ],
        );

        storage = LibraryStorage(databasePath: inMemoryDatabasePath);
        await storage.addBookmark(
          Bookmark(
            bookPath: zeroMultiBook.path,
            positionMs: 0,
            label: 'Start of Tape 1',
          ),
        );

        engine = FakeAudioEngine();
        playerService = AudioPlayerService(
          engine: engine,
          storage: storage,
          fileDurationProbe: (_) async => Duration.zero,
          enablePeriodicSave: false,
        );
        homeCubit = HomeCubit(
          storage: storage,
          scanner: AudiobookScanner(),
          startBackgroundFetchers: false,
          initialState: HomeState(audiobooks: [zeroMultiBook]),
          audioMetadataProbe: (_) async => const AudioFileMetadata(
            duration: Duration.zero,
            bitRate: 0,
            sampleRate: 0,
            channelCount: 0,
            type: AudioType.mp3,
            title: 'Tape',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<HomeCubit>.value(
              value: homeCubit,
              child: PlayerScreen(
                audiobook: zeroMultiBook,
                playerService: playerService,
                storage: storage,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await engine.seek(Duration.zero, index: 1);
        await tester.pump();

        await tester.ensureVisible(find.byTooltip('Show list'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show list'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();

        final startTile = find.widgetWithText(ListTile, 'Start of Tape 1');
        await tester.ensureVisible(startTile);
        await tester.pumpAndSettle();
        await tester.tap(startTile);
        await tester.pumpAndSettle();

        expect(engine.currentIndex, equals(0));
        expect(engine.position, equals(Duration.zero));
      },
    );
  });
}
