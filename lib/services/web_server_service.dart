import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebServerService {
  HttpServer? _server;
  int _port = 8080;
  String? _activePin;
  final Set<String> _validTokens = {};
  final Set<WebSocketChannel> _sockets = {};

  bool get isRunning => _server != null;
  int get port => _port;

  void broadcastPlaybackState(Map<String, dynamic> stateJson) {
    final message = jsonEncode({'type': 'playback', 'data': stateJson});
    for (final socket in _sockets) {
      socket.sink.add(message);
    }
  }

  String generatePin() {
    final rng = Random();
    final pin = (1000 + rng.nextInt(9000)).toString();
    _activePin = pin;
    return pin;
  }

  Future<bool> start({int port = 8080}) async {
    if (isRunning) await stop();
    _port = port;

    final app = Router();

    app.get('/api/health', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'content-type': 'application/json'},
      );
    });

    app.post('/api/verify_pin', (Request request) async {
      final body = await request.readAsString();
      final params = Uri.splitQueryString(body);
      final pin = params['pin'] ?? jsonDecode(body)['pin']?.toString();

      if (_activePin != null && pin == _activePin) {
        final token = 'token_${Random().nextInt(1000000)}';
        _validTokens.add(token);
        return Response.ok(
          jsonEncode({'status': 'ok', 'token': token}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.forbidden(
        jsonEncode({'status': 'error', 'message': 'Invalid PIN'}),
        headers: {'content-type': 'application/json'},
      );
    });

    app.get('/api/library', (Request request) {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.startsWith('Bearer ') == true
          ? authHeader!.substring(7)
          : null;

      if (token == null || !_validTokens.contains(token)) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'categories': <Map<String, dynamic>>[],
          'audiobooks': <Map<String, dynamic>>[],
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    app.get('/api/download', (Request request) {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.startsWith('Bearer ') == true
          ? authHeader!.substring(7)
          : null;

      if (token == null || !_validTokens.contains(token)) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final filePath = request.url.queryParameters['path'];
      if (filePath == null || filePath.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'status': 'error',
            'message': 'Missing path parameter',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        return Response.notFound(
          jsonEncode({'status': 'error', 'message': 'File not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': 'application/octet-stream',
          'content-disposition':
              'attachment; filename="${file.path.split(Platform.pathSeparator).last}"',
        },
      );
    });

    app.post('/api/upload', (Request request) async {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.startsWith('Bearer ') == true
          ? authHeader!.substring(7)
          : null;

      if (token == null || !_validTokens.contains(token)) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final targetPath = request.url.queryParameters['targetPath'];
      if (targetPath == null || targetPath.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'status': 'error',
            'message': 'Missing targetPath parameter',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      try {
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        final sink = file.openWrite();
        await sink.addStream(request.read());
        await sink.close();

        return Response.ok(
          jsonEncode({'status': 'ok', 'message': 'File uploaded successfully'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'error', 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    app.get('/ws/playback', (Request request) {
      final authHeader = request.headers['authorization'] ??
          request.url.queryParameters['token'];
      final token = authHeader?.startsWith('Bearer ') == true
          ? authHeader!.substring(7)
          : authHeader;

      if (token == null || !_validTokens.contains(token)) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Unauthorized'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final wsHandler = webSocketHandler((WebSocketChannel socket, String? protocol) {
        _sockets.add(socket);
        socket.stream.listen(
          (_) {},
          onDone: () => _sockets.remove(socket),
          onError: (_) => _sockets.remove(socket),
        );
      });

      return wsHandler(request);
    });

    // ignore: prefer_const_constructors
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(app.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    for (final socket in _sockets) {
      await socket.sink.close();
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
    _validTokens.clear();
  }
}
