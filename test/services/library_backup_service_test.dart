import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/library_backup_service.dart';
import 'package:audiobook_player/models/audio_eq_profile.dart';

void main() {
  group('Library Backup & Voice Clarity EQ (Ticket 07)', () {
    test('creates Voice Clarity 5-band EQ preset correctly', () {
      final profile = AudioEqProfile.voiceClarity();

      expect(profile.presetName, equals('Voice Clarity'));
      expect(profile.band60Hz, lessThan(0.0)); // Low frequencies cut
      expect(profile.band910Hz, greaterThan(0.0)); // Speech mid-range boosted
      expect(profile.band3600Hz, greaterThan(0.0)); // Voice clarity boosted
    });

    test('serializes and deserializes library backup data correctly', () async {
      final backup = LibraryBackupData(
        version: 1,
        exportedAt: DateTime.now(),
        playbackStates: {'/storage/book1': {'position_ms': 50000, 'playback_speed': 1.5}},
        bookmarks: [{
          'book_path': '/storage/book1',
          'position_ms': 50000,
          'label': 'Chapter 2 Start',
        }],
      );

      final jsonString = backup.toJson();
      final restored = LibraryBackupData.fromJson(jsonString);

      expect(restored.version, equals(1));
      expect(restored.playbackStates.containsKey('/storage/book1'), isTrue);
      expect(restored.bookmarks.length, equals(1));
    });
  });
}
