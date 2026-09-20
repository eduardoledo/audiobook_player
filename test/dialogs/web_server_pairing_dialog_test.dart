import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/dialogs/web_server_pairing_dialog.dart';

void main() {
  testWidgets('WebServerPairingDialog displays PIN and address correctly', (WidgetTester tester) async {
    bool stopped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebServerPairingDialog(
            pin: '5842',
            serverAddress: 'http://192.168.1.50:8080',
            onStopServer: () {
              stopped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Servidor Web Activo'), findsOneWidget);
    expect(find.text('http://192.168.1.50:8080'), findsOneWidget);
    expect(find.text('5842'), findsOneWidget);

    await tester.tap(find.text('Detener Servidor'));
    await tester.pumpAndSettle();

    expect(stopped, isTrue);
  });
}
