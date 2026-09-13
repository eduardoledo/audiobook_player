import 'dart:io';
import 'dart:typed_data';

import 'package:metadata_cli/chapter_phrase_locator.dart';
import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/sherpa_native.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

Future<void> main() async {
  final book =
      '/home/eduardo/Descargas/Books/Audiobooks/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire';
  final audio = p.join(book, '01 - The Final Empire.m4b');
  final epub = parseEpubStructure(
    p.join(book, 'The Final Empire by Brandon Sanderson.epub'),
  );
  final needle = epub.entries.first.firstWordsNormalized;
  final native = await resolveSherpaNativeLibDir();
  sherpa.initBindings(native);
  final home = Platform.environment['HOME']!;
  final modelDir = p.join(home, '.cache', 'metadata_cli', 'whisper_tiny');
  final recognizer = sherpa.OfflineRecognizer(
    sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: p.join(modelDir, 'tiny-encoder.int8.onnx'),
          decoder: p.join(modelDir, 'tiny-decoder.int8.onnx'),
          language: 'en',
          task: 'transcribe',
        ),
        tokens: p.join(modelDir, 'tiny-tokens.txt'),
        modelType: 'whisper',
        numThreads: 4,
        debug: false,
      ),
    ),
  );
  final tmp = await Directory.systemTemp.createTemp('wlen_');
  for (final win in [8.0, 10.0, 12.0]) {
    stdout.writeln('\n=== window=${win}s ===');
    for (final t in [60.0, 64.0, 66.0, 68.0, 70.0, 72.0]) {
      final pcm = await extractPcmWindow(
        audioPath: audio,
        startSeconds: t,
        durationSeconds: win,
        outPath: p.join(tmp.path, 'w.pcm'),
        fastSeek: false,
      );
      if (pcm == null) {
        stdout.writeln('$t FAIL');
        continue;
      }
      final bytes = pcm.readAsBytesSync();
      final bd = ByteData.sublistView(bytes);
      final n = bytes.length ~/ 2;
      final samples = Float32List(n);
      for (var i = 0; i < n; i++) {
        samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
      }
      final stream = recognizer.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text;
      stream.free();
      final depth = progressiveWordMatchCount(text, needle);
      stdout.writeln(
        '${t.toStringAsFixed(0).padLeft(3)}s d=$depth/10 "$text"',
      );
    }
  }
  recognizer.free();
  await tmp.delete(recursive: true);
}
