/// Calculates dynamic short rewind offsets based on pause duration.
class ShortRewindCalculator {
  /// Calculates the rewind [Duration] based on elapsed [pauseDuration].
  static Duration calculateRewind({required Duration pauseDuration}) {
    if (pauseDuration < const Duration(minutes: 5)) {
      return const Duration(seconds: 2);
    } else if (pauseDuration < const Duration(minutes: 15)) {
      return const Duration(seconds: 5);
    } else if (pauseDuration < const Duration(hours: 1)) {
      return const Duration(seconds: 10);
    } else if (pauseDuration < const Duration(hours: 8)) {
      return const Duration(seconds: 20);
    } else {
      return const Duration(seconds: 30);
    }
  }
}
