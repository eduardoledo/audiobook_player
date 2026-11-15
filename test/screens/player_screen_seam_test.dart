import 'package:audiobook_player/bloc/home_cubit.dart';
import 'package:audiobook_player/bloc/home_state.dart';
import 'package:audiobook_player/models/audiobook.dart';
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
          find.descendant(of: bookmarkTile, matching: find.text('02:05')),
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
}
