import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/widgets/home/home_search_bar.dart';

void main() {
  group('HomeSearchBar Widget Tests', () {
    testWidgets('renders search field and filter chips', (tester) async {
      final controller = TextEditingController();
      String query = '';
      LibraryFilter filter = LibraryFilter.all;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return HomeSearchBar(
                  controller: controller,
                  onQueryChanged: (q) => setState(() => query = q),
                  currentFilter: filter,
                  onFilterChanged: (f) => setState(() => filter = f),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Type in query
      await tester.enterText(find.byType(TextField), 'Sanderson');
      await tester.pump();
      expect(query, 'Sanderson');
      expect(controller.text, 'Sanderson');

      // Tap In Progress filter
      await tester.tap(find.text('In Progress'));
      await tester.pump();
      expect(filter, LibraryFilter.inProgress);

      // Tap Completed filter
      await tester.tap(find.text('Completed'));
      await tester.pump();
      expect(filter, LibraryFilter.completed);

      // Clear button
      expect(find.byIcon(Icons.clear), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(query, '');
      expect(controller.text, '');
    });
  });
}
