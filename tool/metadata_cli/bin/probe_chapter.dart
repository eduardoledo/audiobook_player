import 'dart:io';
import 'dart:typed_data';

import 'package:metadata_cli/chapter_phrase_locator.dart';
import 'package:metadata_cli/epub_structure.dart';
import 'package:metadata_cli/sherpa_native.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Probe ASR around a timestamp for a given EPUB entry index.
Future<void> main(List<String> args) async {
  if (args.length < 4) {
    stderr.writeln(
      'Usage: dart run bin/probe_chapter.dart <audio> <epub> <entryIndex> <seconds>',
    );
    exit(64);
  }
  final audio = args[0];
  final epubPath = args[1];
  final index = int.parse(args[2]);
  final center = double.parse(args[3]);

  final epub = parseEpubStructure(epubPath);
  final entry = epub.entries[index];
  stdout.writeln('${entry.title}: «${entry.firstWords}»');
  stdout.writeln('Needle: ${entry.firstWordsNormalized.join(' ')}');
  stdout.writeln('Center: ${_fmt(center)}');

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

  final tmp = await Directory.systemTemp.createTemp('probe_ch_');
  final offsets = <double>[
    for (var d = -90.0; d <= 120.0; d += 10) center + d,
  ];
  final seen = <int>{};

  for (final t in offsets) {
    if (t < 0) continue;
    final k = (t * 10).round();
    if (!seen.add(k)) continue;

    final pcm = await extractPcmWindow(
      audioPath: audio,
      startSeconds: t,
      durationSeconds: 10,
      outPath: p.join(tmp.path, 'w.pcm'),
      fastSeek: true,
    );
    if (pcm == null) {
      stdout.writeln('${_fmt(t)}  EXTRACT_FAIL');
      continue;
    }
    final bytes = await pcm.readAsBytes();
    if (bytes.length < 16000) {
      stdout.writeln('${_fmt(t)}  short');
      continue;
    }
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
    final depth =
        progressiveWordMatchCount(text, entry.firstWordsNormalized);
    final mark = depth >= 3 ? ' <<<' : '';
    stdout.writeln(
      '${_fmt(t)}  depth=$depth/${entry.firstWordsNormalized.length}  "$text"$mark',
    );
  }

  recognizer.free();
  await tmp.delete(recursive: true);
}

String _fmt(double s) {
  final sec = s.round();
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final r = sec % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${r.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:'
      '${r.toString().padLeft(2, '0')}';
}
