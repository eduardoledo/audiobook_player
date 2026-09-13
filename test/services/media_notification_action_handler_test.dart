import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/media_notification_action_handler.dart';

void main() {
  group('MediaNotificationActionHandler (Ticket 06)', () {
    test('dispatches custom background notification actions correctly', () async {
      String? dispatchedAction;

      final handler = MediaNotificationActionHandler(
        onRewind: () => dispatchedAction = 'rewind_10s',
        onFastForward: () => dispatchedAction = 'fast_forward_30s',
        onAddBookmark: () => dispatchedAction = 'add_bookmark',
        onExtendSleepTimer: () => dispatchedAction = 'extend_sleep',
      );

      await handler.handleAction('action_rewind_10s');
      expect(dispatchedAction, equals('rewind_10s'));

      await handler.handleAction('action_extend_sleep');
      expect(dispatchedAction, equals('extend_sleep'));
    });
  });
}
