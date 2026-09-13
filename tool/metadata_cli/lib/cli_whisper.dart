import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads and caches sherpa-onnx Whisper tiny for the CLI.
class CliWhisperModelManager {
  static const _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

  static const _files = {
    'tiny-encoder.int8.onnx': '$_baseUrl/tiny-encoder.int8.onnx',
    'tiny-decoder.int8.onnx': '$_baseUrl/tiny-decoder.int8.onnx',
    'tiny-tokens.txt': '$_baseUrl/tiny-tokens.txt',
  };

  final Directory modelDir;

  CliWhisperModelManager({Directory? modelDir})
      : modelDir = modelDir ??
            Directory(
              p.join(
                Platform.environment['HOME'] ?? Directory.systemTemp.path,
                '.cache',
                'metadata_cli',
                'whisper_tiny',
              ),
            );

  String get encoderPath => p.join(modelDir.path, 'tiny-encoder.int8.onnx');
  String get decoderPath => p.join(modelDir.path, 'tiny-decoder.int8.onnx');
  String get tokensPath => p.join(modelDir.path, 'tiny-tokens.txt');

  Future<bool> isModelReady() async {
    for (final name in _files.keys) {
      final f = File(p.join(modelDir.path, name));
      if (!await f.exists() || await f.length() < 1024) return false;
    }
    return true;
  }

  Future<void> ensureModel({
    void Function(String status)? onStatus,
  }) async {
    if (await isModelReady()) {
      onStatus?.call('Whisper tiny already cached at ${modelDir.path}');
      return;
    }
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    for (final entry in _files.entries) {
      final dest = File(p.join(modelDir.path, entry.key));
      if (await dest.exists() && await dest.length() > 1024) continue;
      onStatus?.call('Downloading ${entry.key}…');
      final resp = await http.get(Uri.parse(entry.value));
      if (resp.statusCode != 200) {
        throw StateError(
          'Failed to download ${entry.key}: HTTP ${resp.statusCode}',
        );
      }
      await dest.writeAsBytes(resp.bodyBytes);
    }
    onStatus?.call('Whisper tiny ready');
  }
}
