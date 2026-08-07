import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches sherpa-onnx Whisper tiny (multilingual, int8).
class WhisperModelManager {
  static const _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

  static const _files = {
    'tiny-encoder.int8.onnx': '$_baseUrl/tiny-encoder.int8.onnx',
    'tiny-decoder.int8.onnx': '$_baseUrl/tiny-decoder.int8.onnx',
    'tiny-tokens.txt': '$_baseUrl/tiny-tokens.txt',
  };

  Directory? _modelDir;

  Future<Directory> get modelDir async {
    if (_modelDir != null) return _modelDir!;
    final docs = await getApplicationSupportDirectory();
    _modelDir = Directory(p.join(docs.path, 'whisper_tiny'));
    if (!await _modelDir!.exists()) {
      await _modelDir!.create(recursive: true);
    }
    return _modelDir!;
  }

  Future<String> get encoderPath async =>
      p.join((await modelDir).path, 'tiny-encoder.int8.onnx');

  Future<String> get decoderPath async =>
      p.join((await modelDir).path, 'tiny-decoder.int8.onnx');

  Future<String> get tokensPath async =>
      p.join((await modelDir).path, 'tiny-tokens.txt');

  Future<bool> isModelReady() async {
    for (final name in _files.keys) {
      final f = File(p.join((await modelDir).path, name));
      if (!await f.exists() || await f.length() < 1024) return false;
    }
    return true;
  }

  static String _friendlyName(String fileName) {
    if (fileName.contains('encoder')) return 'codificador';
    if (fileName.contains('decoder')) return 'decodificador';
    if (fileName.contains('tokens')) return 'vocabulario';
    return fileName;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Ensures model files exist. [onProgress] receives 0.0–1.0 and detail text.
  Future<void> ensureModel({
    void Function(double progress, String status, String detail)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (await isModelReady()) {
      onProgress?.call(
        1.0,
        'Modelo listo',
        'Whisper tiny ya está en caché; no hace falta descargar.',
      );
      return;
    }

    final dir = await modelDir;
    final entries = _files.entries.toList();
    var completed = 0;

    for (final entry in entries) {
      if (isCancelled?.call() == true) {
        throw StateError('cancelled');
      }

      final friendly = _friendlyName(entry.key);
      final fileIndex = completed + 1;
      final dest = File(p.join(dir.path, entry.key));
      if (await dest.exists() && await dest.length() > 1024) {
        completed++;
        onProgress?.call(
          completed / entries.length,
          'Archivo en caché',
          'Usando $friendly (${entry.key}) — '
              'archivo $fileIndex de ${entries.length}.',
        );
        continue;
      }

      onProgress?.call(
        completed / entries.length,
        'Descargando modelo',
        'Descargando $friendly (${entry.key}) — '
            'archivo $fileIndex de ${entries.length}. '
            'Solo se descarga la primera vez.',
      );

      final request = http.Request('GET', Uri.parse(entry.value));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download ${entry.key}: HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? 0;
      final sink = dest.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        if (isCancelled?.call() == true) {
          await sink.close();
          if (await dest.exists()) await dest.delete();
          throw StateError('cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final fileFrac = received / total;
          final overall = (completed + fileFrac) / entries.length;
          onProgress?.call(
            overall,
            'Descargando modelo',
            'Descargando $friendly: ${_formatBytes(received)} de '
                '${_formatBytes(total)} '
                '(archivo $fileIndex de ${entries.length}).',
          );
        } else {
          onProgress?.call(
            completed / entries.length,
            'Descargando modelo',
            'Descargando $friendly: ${_formatBytes(received)} recibidos '
                '(archivo $fileIndex de ${entries.length}).',
          );
        }
      }
      await sink.close();
      completed++;
      onProgress?.call(
        completed / entries.length,
        'Archivo descargado',
        'Listo $friendly (${entry.key}).',
      );
    }

    onProgress?.call(
      1.0,
      'Modelo listo',
      'Todos los archivos de Whisper tiny están disponibles.',
    );
  }
}
