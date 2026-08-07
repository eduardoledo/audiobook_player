import 'package:audiobook_player/services/whisper_asr_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhisperAsrWorkerProtocol', () {
    test('init command shape', () {
      final cmd = WhisperAsrWorkerProtocol.initCommand(
        id: 1,
        encoder: '/e.onnx',
        decoder: '/d.onnx',
        tokens: '/t.txt',
        language: 'es',
        numThreads: 3,
      );
      expect(cmd['cmd'], 'init');
      expect(cmd['language'], 'es');
      expect(cmd['numThreads'], 3);
      expect(cmd['id'], 1);
    });

    test('transcribe command shape', () {
      final cmd = WhisperAsrWorkerProtocol.transcribeCommand(
        id: 2,
        pcmPath: '/tmp/a.pcm',
      );
      expect(cmd['cmd'], 'transcribe');
      expect(cmd['pcmPath'], '/tmp/a.pcm');
      expect(cmd['sampleRate'], 16000);
    });

    test('isOk', () {
      expect(WhisperAsrWorkerProtocol.isOk({'ok': true}), isTrue);
      expect(WhisperAsrWorkerProtocol.isOk({'ok': false}), isFalse);
    });
  });
}
