import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/book_status_calculator.dart';

void main() {
  group('BookStatusCalculator (Ticket 04)', () {
    test('returns New status when book has never been started', () {
      final status = BookStatusCalculator.calculateStatus(
        progressPercent: 0.0,
        hasBeenStarted: false,
      );
      expect(status, equals(BookStatus.newBook));
    });

    test('returns In Progress status when started and progress is under 98%', () {
      final status = BookStatusCalculator.calculateStatus(
        progressPercent: 0.45,
        hasBeenStarted: true,
      );
      expect(status, equals(BookStatus.inProgress));
    });

    test('returns Finished status when progress reaches or exceeds 98%', () {
      final status = BookStatusCalculator.calculateStatus(
        progressPercent: 0.985,
        hasBeenStarted: true,
      );
      expect(status, equals(BookStatus.finished));
    });
  });
}
