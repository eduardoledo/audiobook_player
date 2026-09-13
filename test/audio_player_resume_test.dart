import 'package:audiobook_player/services/audio_player_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlayerService.positionForResume', () {
    test('rewinds exactly one second', () {
      expect(
        AudioPlayerService.positionForResume(const Duration(seconds: 90)),
        const Duration(seconds: 89),
      );
      expect(
        AudioPlayerService.resumeRewind,
        const Duration(seconds: 1),
      );
    });

    test('floors at zero when saved position is at or under one second', () {
      expect(
        AudioPlayerService.positionForResume(const Duration(milliseconds: 1000)),
        Duration.zero,
      );
      expect(
        AudioPlayerService.positionForResume(const Duration(milliseconds: 400)),
        Duration.zero,
      );
      expect(
        AudioPlayerService.positionForResume(Duration.zero),
        Duration.zero,
      );
    });
  });
}
