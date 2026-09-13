import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SleepTimer & PlaybackSpeed Sheet Widget Tests', () {
    testWidgets('SleepTimerSheet renders options correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => const _MockSleepTimerView(),
                      );
                    },
                    child: const Text('Open Sleep Timer'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sleep Timer'));
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('15 minutes'), findsOneWidget);
      expect(find.text('End of chapter'), findsOneWidget);
    });

    testWidgets('PlaybackSpeedSheet renders speed options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => const _MockSpeedView(),
                      );
                    },
                    child: const Text('Open Speed'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Speed'));
      await tester.pumpAndSettle();

      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });
  });
}

class _MockSleepTimerView extends StatelessWidget {
  const _MockSleepTimerView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text('Sleep Timer'),
        ListTile(title: Text('Off')),
        ListTile(title: Text('15 minutes')),
        ListTile(title: Text('End of chapter')),
      ],
    );
  }
}

class _MockSpeedView extends StatelessWidget {
  const _MockSpeedView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text('Speed'),
        ListTile(title: Text('1.0x')),
        ListTile(title: Text('1.5x')),
        ListTile(title: Text('2.0x')),
      ],
    );
  }
}
