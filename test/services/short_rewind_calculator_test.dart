import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/short_rewind_calculator.dart';

void main() {
  group('ShortRewindCalculator', () {
    test('returns 2s (2000ms) rewind for pause duration under 5 minutes', () {
      final rewind = ShortRewindCalculator.calculateRewind(
        pauseDuration: const Duration(minutes: 2),
      );
      expect(rewind, equals(const Duration(seconds: 2)));
    });

    test('returns 5s (5000ms) rewind for pause duration between 5 and 15 minutes', () {
      final rewind = ShortRewindCalculator.calculateRewind(
        pauseDuration: const Duration(minutes: 10),
      );
      expect(rewind, equals(const Duration(seconds: 5)));
    });

    test('returns 10s (10000ms) rewind for pause duration between 15 and 60 minutes', () {
      final rewind = ShortRewindCalculator.calculateRewind(
        pauseDuration: const Duration(minutes: 30),
      );
      expect(rewind, equals(const Duration(seconds: 10)));
    });

    test('returns 20s (20000ms) rewind for pause duration between 1 and 8 hours', () {
      final rewind = ShortRewindCalculator.calculateRewind(
        pauseDuration: const Duration(hours: 3),
      );
      expect(rewind, equals(const Duration(seconds: 20)));
    });

    test('returns 30s (30000ms) rewind for pause duration over 8 hours', () {
      final rewind = ShortRewindCalculator.calculateRewind(
        pauseDuration: const Duration(hours: 10),
      );
      expect(rewind, equals(const Duration(seconds: 30)));
    });
  });
}
