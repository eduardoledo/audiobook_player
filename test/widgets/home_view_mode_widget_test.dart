import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/screens/home_screen.dart';
import 'package:audiobook_player/bloc/home_cubit.dart';
import 'package:audiobook_player/bloc/home_state.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/models/category_node.dart';
import 'package:audiobook_player/l10n/app_localizations.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audiobook_player/services/structure_detection_job.dart';
import 'package:audiobook_player/service_locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MockHomeCubit extends Cubit<HomeState> implements HomeCubit {
  MockHomeCubit(super.initialState);

  @override
  Future<void> toggleViewMode() async {
    final next = state.viewMode == 'grid' ? 'list' : 'grid';
    emit(state.copyWith(viewMode: next));
  }

  @override
  Future<void> loadData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibraryStorage extends Fake implements LibraryStorage {
  @override
  Future<String?> getLastPlayedBook() async => null;
  @override
  Future<String> getLibraryViewMode() async => 'list';
  @override
  Future<void> saveLibraryViewMode(String mode) async {}
}

class FakeStructureDetectionJob extends ChangeNotifier implements StructureDetectionJob {
  @override
  bool get hasJob => false;
  @override
  bool get panelOpen => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final originalOnError = FlutterError.onError;

  setUpAll(() {
    FlutterError.onError = (FlutterErrorDetails details) {};
  });

  tearDownAll(() {
    FlutterError.onError = originalOnError;
  });

  setUp(() {
    getIt.reset();
    getIt.registerSingleton<LibraryStorage>(FakeLibraryStorage());
    getIt.registerSingleton<StructureDetectionJob>(FakeStructureDetectionJob());
  });

  group('Ticket 02 & 03: HomeScreen View Mode & Accordion UI Tests', () {
    testWidgets('renders view switcher toggle button in AppBar and toggles mode', (tester) async {
      final cubit = MockHomeCubit(const HomeState(viewMode: 'list'));

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final defaultOnError = FlutterError.onError;
      FlutterError.onError = (details) {};
      addTearDown(() => FlutterError.onError = defaultOnError);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<HomeCubit>.value(
            value: cubit,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      final toggleFinder = find.byTooltip('Cambiar a vista de cuadrícula');
      expect(toggleFinder, findsOneWidget);

      await cubit.toggleViewMode();
      await tester.pump();

      expect(cubit.state.viewMode, equals('grid'));
      expect(find.byTooltip('Cambiar a vista de lista'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('renders accordion category tile with duration and book count', (tester) async {
      const categoryNode = CategoryNode(
        id: 1,
        name: 'Brandon Sanderson',
        lft: 1,
        rgt: 4,
        depth: 0,
        pathPrefix: 'Brandon Sanderson',
      );

      const book = Audiobook(
        path: '/books/elantris.m4b',
        title: 'Elantris',
        author: 'Brandon Sanderson',
        durationFormatted: '01:00:00.000',
        files: ['elantris.m4b'],
        totalChapters: 1,
        chapters: [],
        categoryId: 1,
      );

      const initialState = HomeState(
        categories: [categoryNode],
        audiobooks: [book],
        viewMode: 'list',
        scanPaths: ['/books'],
      );

      final cubit = MockHomeCubit(initialState);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final defaultOnError = FlutterError.onError;
      FlutterError.onError = (details) {};
      addTearDown(() => FlutterError.onError = defaultOnError);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<HomeCubit>.value(
            value: cubit,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ExpansionTile), findsAtLeastNWidgets(1));
      expect(find.text('Brandon Sanderson'), findsAtLeastNWidgets(1));
      expect(find.text('Elantris'), findsOneWidget);
      expect(find.textContaining('1 libro'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsAtLeastNWidgets(1));

      await cubit.close();
    });
  });
}
