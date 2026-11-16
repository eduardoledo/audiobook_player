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

        final savedBookmarks = await storage.getBookmarksForBook(book.path);
        expect(savedBookmarks.length, equals(1));
        expect(savedBookmarks.first.label, equals('Kelsier arrives'));
        expect(savedBookmarks.first.positionMs, equals(125000));

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
}
