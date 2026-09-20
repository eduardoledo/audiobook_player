import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class WebServerService {
  HttpServer? _server;
  int _port = 8080;
  String? _activePin;
  final Set<String> _validTokens = {};

  bool get isRunning => _server != null;
  int get port => _port;

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

    // ignore: prefer_const_constructors
    final handler = Pipeline().addMiddleware(logRequests()).addHandler(app.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _validTokens.clear();
  }
}
