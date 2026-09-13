import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/smart_sleep_timer_service.dart';

void main() {
  group('SmartSleepTimerService (Ticket 02)', () {
    late SmartSleepTimerService timerService;

    setUp(() {
      timerService = SmartSleepTimerService();
    });

    tearDown(() {
      timerService.cancel();
    });

    test('countdown expires and triggers onExpired callback when time reaches 0', () async {
      bool expired = false;

      timerService.start(
        duration: const Duration(milliseconds: 100),
        onExpired: () {
          expired = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 150));
      expect(expired, isTrue);
    });

    test('enables motion listening exclusively during the final 2 minutes warning window', () async {
      timerService.start(
        duration: const Duration(minutes: 5),
        onExpired: () {},
      );

      expect(timerService.isListeningToMotion, isFalse);

      // Fast forward to remaining 1 minute 30 seconds
      timerService.setRemainingTimeForTesting(const Duration(minutes: 1, seconds: 30));
      expect(timerService.isListeningToMotion, isTrue);
    });

    test('motion detection event resets countdown timer back to initial duration', () async {
      timerService.start(
        duration: const Duration(minutes: 10),
        onExpired: () {},
      );

      timerService.setRemainingTimeForTesting(const Duration(seconds: 30));
      expect(timerService.isListeningToMotion, isTrue);

      timerService.handleMotionDetected();

      expect(timerService.remainingTime, equals(const Duration(minutes: 10)));
      expect(timerService.isListeningToMotion, isFalse);
    });
  });
}
