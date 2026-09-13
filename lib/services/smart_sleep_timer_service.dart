import 'dart:async';

/// Smart Sleep Timer with motion detection grace window.
class SmartSleepTimerService {
  Timer? _timer;
  Duration _initialDuration = Duration.zero;
  Duration _remainingTime = Duration.zero;
  void Function()? _onExpired;
  bool _isListeningToMotion = false;

  bool get isListeningToMotion => _isListeningToMotion;
  Duration get remainingTime => _remainingTime;

  void start({required Duration duration, required void Function() onExpired}) {
    cancel();
    _initialDuration = duration;
    _remainingTime = duration;
    _onExpired = onExpired;
    _updateMotionListeningState();

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_remainingTime <= const Duration(milliseconds: 50)) {
        cancel();
        _onExpired?.call();
      } else {
        _remainingTime -= const Duration(milliseconds: 50);
        _updateMotionListeningState();
      }
    });
  }

  void _updateMotionListeningState() {
    if (_remainingTime > Duration.zero && _remainingTime <= const Duration(minutes: 2)) {
      _isListeningToMotion = true;
    } else {
      _isListeningToMotion = false;
    }
  }

  void handleMotionDetected() {
    if (_isListeningToMotion) {
      reset();
    }
  }

  void reset() {
    if (_initialDuration > Duration.zero && _onExpired != null) {
      start(duration: _initialDuration, onExpired: _onExpired!);
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remainingTime = Duration.zero;
    _isListeningToMotion = false;
  }

  void setRemainingTimeForTesting(Duration duration) {
    _remainingTime = duration;
    _updateMotionListeningState();
  }
}
