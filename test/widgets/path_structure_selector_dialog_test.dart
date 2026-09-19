import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/models/path_pattern_rule.dart';
import 'package:audiobook_player/models/path_pattern_conflict_result.dart';
import 'package:audiobook_player/services/library_storage.dart';
import 'package:audiobook_player/service_locator.dart';

class FakeLibraryStorage extends Fake implements LibraryStorage {
  final Map<String, PathPatternRule> rules = {};

  @override
  Future<Map<String, PathPatternRule>> getPathPatternRules() async => rules;

  @override
  Future<void> savePathPatternRule(PathPatternRule rule) async {
    rules[rule.rootPath] = rule;
  }

  @override
  Future<PathPatternConflictResult> validatePathPatternConflict(PathPatternRule targetRule) async {
    if (rules.containsKey('/audiobooks')) {
      return const PathPatternConflictResult(
        hasConflict: true,
        conflictingRule: PathPatternRule(
          rootPath: '/audiobooks',
          roles: [PathSegmentRole.author, PathSegmentRole.saga, PathSegmentRole.bookTitle],
        ),
        reason: 'La ruta del patrón ("/audiobooks/Brandon Sanderson") se solapa con un patrón existente ("/audiobooks").',
      );
    }
    return PathPatternConflictResult.clean;
  }
}

void main() {
  group('Ticket 01: PathStructureSelectorDialog Conflict UI Tests', () {
    late FakeLibraryStorage storage;

    setUp(() {
      getIt.reset();
      storage = FakeLibraryStorage();
      getIt.registerSingleton<LibraryStorage>(storage);
    });

    testWidgets('presents conflict choice modal when saving conflicting pattern and respects Mantener choice', (tester) async {
      await storage.savePathPatternRule(const PathPatternRule(
        rootPath: '/audiobooks',
        roles: [PathSegmentRole.author, PathSegmentRole.saga, PathSegmentRole.bookTitle],
      ));

      const targetRule = PathPatternRule(
        rootPath: '/audiobooks/Brandon Sanderson',
        roles: [PathSegmentRole.saga, PathSegmentRole.bookTitle],
      );

      final conflict = await storage.validatePathPatternConflict(targetRule);
      expect(conflict.hasConflict, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Conflicto de Patrón Detectado'),
                      content: Text(conflict.reason!),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Mantener Patrón Anterior'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Reemplazar con Nuevo Patrón'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Conflicto de Patrón Detectado'), findsOneWidget);
      expect(find.text('Mantener Patrón Anterior'), findsOneWidget);
      expect(find.text('Reemplazar con Nuevo Patrón'), findsOneWidget);

      await tester.tap(find.text('Mantener Patrón Anterior'));
      await tester.pumpAndSettle();

      final rules = await storage.getPathPatternRules();
      expect(rules.containsKey('/audiobooks/Brandon Sanderson'), isFalse);
    });
  });
}
