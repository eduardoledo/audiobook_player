import 'dart:async';

/// Handler for extended background media notification actions (Ticket 06).
class MediaNotificationActionHandler {
  final FutureOr<void> Function()? onRewind;
  final FutureOr<void> Function()? onFastForward;
  final FutureOr<void> Function()? onAddBookmark;
  final FutureOr<void> Function()? onExtendSleepTimer;

  const MediaNotificationActionHandler({
    this.onRewind,
    this.onFastForward,
    this.onAddBookmark,
    this.onExtendSleepTimer,
  });

  Future<void> handleAction(String action) async {
    switch (action) {
      case 'action_rewind_10s':
        await onRewind?.call();
        break;
      case 'action_fast_forward_30s':
        await onFastForward?.call();
        break;
      case 'action_add_bookmark':
        await onAddBookmark?.call();
        break;
      case 'action_extend_sleep':
        await onExtendSleepTimer?.call();
        break;
    }
  }
}
