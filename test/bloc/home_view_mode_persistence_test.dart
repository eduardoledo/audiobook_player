import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audiobook_player/services/audiobook_scanner.dart';
import 'package:audiobook_player/bloc/home_cubit.dart';
import 'package:audiobook_player/bloc/home_state.dart';
import 'package:audiobook_player/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ticket 01: View Mode State & SQLite Settings Persistence', () {
    late LibraryStorage storage;

    setUp(() async {
      storage = LibraryStorage();
      if (!getIt.isRegistered<LibraryStorage>()) {
        getIt.registerSingleton<LibraryStorage>(storage);
      }
      if (!getIt.isRegistered<AudiobookScanner>()) {
        getIt.registerSingleton<AudiobookScanner>(AudiobookScanner());
      }
      final db = await storage.database;
      await db.delete('settings', where: 'key = ?', whereArgs: ['main_library_view_mode']);
    });

    test('getLibraryViewMode defaults to list when empty', () async {
      final mode = await storage.getLibraryViewMode();
      expect(mode, equals('list'));
    });

    test('saveLibraryViewMode saves and retrieves grid view mode', () async {
      await storage.saveLibraryViewMode('grid');
      final mode = await storage.getLibraryViewMode();
      expect(mode, equals('grid'));
    });

    test('HomeState includes viewMode defaulting to list', () {
      const state = HomeState();
      expect(state.viewMode, equals('list'));

      final updated = state.copyWith(viewMode: 'grid');
      expect(updated.viewMode, equals('grid'));
      expect(updated.props, contains('grid'));
    });

    test('HomeCubit toggleViewMode updates state and persists preference', () async {
      final cubit = HomeCubit();
      expect(cubit.state.viewMode, equals('list'));

      await cubit.toggleViewMode();
      expect(cubit.state.viewMode, equals('grid'));

      final savedMode = await storage.getLibraryViewMode();
      expect(savedMode, equals('grid'));

      await cubit.close();
    });
  });
}
