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
  final epubPath = p.join(book, 'The Final Empire by Brandon Sanderson.epub');
  final epub = parseEpubStructure(epubPath);
  final needle = epub.entries.first.firstWordsNormalized;
  stdout.writeln('Needle: ${needle.join(' ')}');

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
  final tmp = await Directory.systemTemp.createTemp('seek_exp_');

  final times = [0.0, 48.0, 60.0, 64.0, 68.0, 72.0, 75.0, 79.0, 84.0, 96.0, 450.0];
  for (final fast in [true, false]) {
    stdout.writeln('\n=== fastSeek=$fast window=6s ===');
    for (final t in times) {
      final pcm = await extractPcmWindow(
        audioPath: audio,
        startSeconds: t,
        durationSeconds: 6,
        outPath: p.join(tmp.path, 'w.pcm'),
        fastSeek: fast,
      );
      if (pcm == null) {
        stdout.writeln('${_fmt(t)} EXTRACT_FAIL');
        continue;
      }
      final text = _transcribe(recognizer, pcm);
      final depth = text == null ? 0 : progressiveWordMatchCount(text, needle);
      stdout.writeln(
        '${_fmt(t)} depth=$depth/10  "${(text ?? '').replaceAll('\n', ' ')}"',
      );
    }
  }
  recognizer.free();
  await tmp.delete(recursive: true);
}

String? _transcribe(sherpa.OfflineRecognizer recognizer, File pcmFile) {
  final bytes = pcmFile.readAsBytesSync();
  if (bytes.length < 16000) return null;
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
  return text;
}

String _fmt(double s) {
  final sec = s.round();
  final m = sec ~/ 60;
  final r = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}
