import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Long-lived isolate that owns Whisper [OfflineRecognizer].
///
/// Never pass the recognizer across isolates — create it only inside the worker
/// after [sherpa.initBindings].
class WhisperAsrWorker {
  Isolate? _isolate;
  SendPort? _workerPort;
  final ReceivePort _mainPort = ReceivePort();
  StreamSubscription? _sub;
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  String? _language;
  bool _ready = false;

  bool get isReady => _ready;
  String? get language => _language;

  Future<void> ensureStarted() async {
    if (_workerPort != null) return;
    final ready = Completer<SendPort>();
    _sub = _mainPort.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is Map) {
        final id = message['id'] as int?;
        if (id != null && _pending.containsKey(id)) {
          _pending.remove(id)!.complete(Map<String, dynamic>.from(message));
        }
      }
    });
    _isolate = await Isolate.spawn(
      _whisperAsrWorkerMain,
      _mainPort.sendPort,
      debugName: 'whisper_asr_worker',
    );
    _workerPort = await ready.future;
  }

  Future<void> init({
    required String encoderPath,
    required String decoderPath,
    required String tokensPath,
    required String language,
    int numThreads = 3,
  }) async {
    await ensureStarted();
    if (_ready && _language == language) return;

    final response = await _send({
      'cmd': 'init',
      'encoder': encoderPath,
      'decoder': decoderPath,
      'tokens': tokensPath,
      'language': language,
      'numThreads': numThreads,
    });
    if (response['ok'] != true) {
      throw StateError(response['error']?.toString() ?? 'ASR init failed');
    }
    _language = language;
    _ready = true;
  }

  Future<String?> transcribe({
    required String pcmPath,
    required int sampleRate,
  }) async {
    if (!_ready) {
      throw StateError('WhisperAsrWorker not initialized');
    }
    final response = await _send({
      'cmd': 'transcribe',
      'pcmPath': pcmPath,
      'sampleRate': sampleRate,
    });
    if (response['ok'] != true) {
      final err = response['error']?.toString();
      if (err != null && err.isNotEmpty) {
        // Soft-fail empty/short windows
        return null;
      }
      return null;
    }
    final text = response['text'] as String?;
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  Future<void> shutdown() async {
    if (_workerPort != null) {
      try {
        await _send({'cmd': 'shutdown'}, timeout: const Duration(seconds: 2));
      } catch (_) {}
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerPort = null;
    _ready = false;
    _language = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('worker shutdown'));
      }
    }
    _pending.clear();
    await _sub?.cancel();
    _sub = null;
    _mainPort.close();
  }

  Future<Map<String, dynamic>> _send(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final port = _workerPort;
    if (port == null) throw StateError('worker not started');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    port.send({...payload, 'id': id});
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('ASR worker timeout', timeout);
    });
  }
}

/// Top-level isolate entry (must be top-level or static).
void _whisperAsrWorkerMain(SendPort mainSendPort) {
  sherpa.initBindings();

  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  sherpa.OfflineRecognizer? recognizer;

  Float32List pcm16ToFloat32(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  port.listen((message) {
    if (message is! Map) return;
    final map = Map<String, dynamic>.from(message);
    final id = map['id'] as int? ?? 0;
    final cmd = map['cmd'] as String? ?? '';

    try {
      switch (cmd) {
        case 'init':
          recognizer?.free();
          recognizer = null;
          final whisper = sherpa.OfflineWhisperModelConfig(
            encoder: map['encoder'] as String,
            decoder: map['decoder'] as String,
            language: map['language'] as String? ?? '',
            task: 'transcribe',
          );
          final model = sherpa.OfflineModelConfig(
            whisper: whisper,
            tokens: map['tokens'] as String,
            modelType: 'whisper',
            numThreads: map['numThreads'] as int? ?? 3,
          );
          recognizer = sherpa.OfflineRecognizer(
            sherpa.OfflineRecognizerConfig(model: model),
          );
          mainSendPort.send({'id': id, 'ok': true});
          break;

        case 'transcribe':
          final rec = recognizer;
          if (rec == null) {
            mainSendPort.send({
              'id': id,
              'ok': false,
              'error': 'recognizer not init',
            });
            break;
          }
          final pcmPath = map['pcmPath'] as String;
          final sampleRate = map['sampleRate'] as int? ?? 16000;
          final file = File(pcmPath);
          if (!file.existsSync()) {
            mainSendPort.send({
              'id': id,
              'ok': false,
              'error': 'pcm missing',
            });
            break;
          }
          final bytes = file.readAsBytesSync();
          if (bytes.length < sampleRate) {
            mainSendPort.send({'id': id, 'ok': true, 'text': ''});
            break;
          }
          final samples = pcm16ToFloat32(bytes);
          final stream = rec.createStream();
          stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
          rec.decode(stream);
          final text = rec.getResult(stream).text;
          stream.free();
          mainSendPort.send({'id': id, 'ok': true, 'text': text});
          break;

        case 'shutdown':
          recognizer?.free();
          recognizer = null;
          mainSendPort.send({'id': id, 'ok': true});
          port.close();
          break;

        default:
          mainSendPort.send({
            'id': id,
            'ok': false,
            'error': 'unknown cmd $cmd',
          });
      }
    } catch (e) {
      mainSendPort.send({'id': id, 'ok': false, 'error': e.toString()});
    }
  });
}

/// Message-protocol helpers for unit tests (no real isolate).
class WhisperAsrWorkerProtocol {
  static Map<String, dynamic> initCommand({
    required int id,
    required String encoder,
    required String decoder,
    required String tokens,
    required String language,
    int numThreads = 3,
  }) =>
      {
        'cmd': 'init',
        'id': id,
        'encoder': encoder,
        'decoder': decoder,
        'tokens': tokens,
        'language': language,
        'numThreads': numThreads,
      };

  static Map<String, dynamic> transcribeCommand({
    required int id,
    required String pcmPath,
    int sampleRate = 16000,
  }) =>
      {
        'cmd': 'transcribe',
        'id': id,
        'pcmPath': pcmPath,
        'sampleRate': sampleRate,
      };

  static bool isOk(Map<String, dynamic> response) => response['ok'] == true;
}
