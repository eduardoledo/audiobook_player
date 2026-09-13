import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import 'package:audiobook_player/dialogs/path_structure_selector_dialog.dart';
import 'package:audiobook_player/models/path_pattern_rule.dart';
import 'package:audiobook_player/services/library_storage.dart';

class FakeLibraryStorage extends Fake implements LibraryStorage {
  final List<String> scanPaths;
  final Map<String, PathPatternRule> rules;

  FakeLibraryStorage({
    this.scanPaths = const [],
    this.rules = const {},
  });

  @override
  Future<List<String>> getScanPaths() async => scanPaths;

  @override
  Future<Map<String, PathPatternRule>> getPathPatternRules() async => rules;
}

void main() {
  late FakeLibraryStorage fakeStorage;

  setUp(() {
    GetIt.I.reset();
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('PathStructureSelectorDialog loads existing scan roots and resolves relative segments', (WidgetTester tester) async {
    final rootPath = p.normalize('/tmp/non_existent_test_library');
    final subPath = p.normalize('/tmp/non_existent_test_library/Author/Universe/Saga/BookTitle');

    fakeStorage = FakeLibraryStorage(
      scanPaths: [rootPath],
      rules: {},
    );
    GetIt.I.registerSingleton<LibraryStorage>(fakeStorage);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathStructureSelectorDialog(rootPath: subPath),
        ),
      ),
    );

    // Pump a frame and wait for async _loadStructure to finish
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Estructura de la Ruta'), findsOneWidget);
  });
}
