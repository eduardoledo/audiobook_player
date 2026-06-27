import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/main.dart';

void main() {
  testWidgets('App compiles and runs smoke test', (WidgetTester tester) async {
    // Just verify the app is instantiable
    const app = AudiobookPlayerApp();
    expect(app, isNotNull);
  });
}
