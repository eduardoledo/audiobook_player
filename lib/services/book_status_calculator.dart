/// Classification status of an Audiobook within the library.
enum BookStatus {
  newBook,
  inProgress,
  finished,
}

/// Pure domain calculator for Audiobook lifecycle status transitions.
class BookStatusCalculator {
  static BookStatus calculateStatus({
    required double progressPercent,
    required bool hasBeenStarted,
  }) {
    if (progressPercent >= 0.98) {
      return BookStatus.finished;
    } else if (hasBeenStarted) {
      return BookStatus.inProgress;
    } else {
      return BookStatus.newBook;
    }
  }
}
