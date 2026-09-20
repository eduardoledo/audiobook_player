import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:audiobook_player/services/web_server_service.dart';

void main() {
  group('WebServerService Engine Tests', () {
    late WebServerService serverService;

    setUp(() {
      serverService = WebServerService();
    });

    tearDown(() async {
      await serverService.stop();
    });

    test('starts server on specified port and responds to health endpoint', () async {
      final success = await serverService.start(port: 9876);
      expect(success, isTrue);
      expect(serverService.isRunning, isTrue);

      final response = await http.get(Uri.parse('http://127.0.0.1:9876/api/health'));
      expect(response.statusCode, equals(200));
      expect(response.body, contains('ok'));
    });

    test('generates and verifies 4-digit PIN for session token', () async {
      await serverService.start(port: 9877);
      final pin = serverService.generatePin();
      expect(pin.length, equals(4));

      final verifyResponse = await http.post(
        Uri.parse('http://127.0.0.1:9877/api/verify_pin'),
        body: {'pin': pin},
      );
      expect(verifyResponse.statusCode, equals(200));
      expect(verifyResponse.body, contains('token'));
    });

    test('returns 401 on /api/library without valid token and 200 with categories when paired', () async {
      await serverService.start(port: 9878);

      // Unauthorized check
      final unauthResponse = await http.get(Uri.parse('http://127.0.0.1:9878/api/library'));
      expect(unauthResponse.statusCode, equals(401));

      // Obtain token via PIN
      final pin = serverService.generatePin();
      final verifyResponse = await http.post(
        Uri.parse('http://127.0.0.1:9878/api/verify_pin'),
        body: {'pin': pin},
      );
      final body = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
      final token = body['token'] as String;

      // Authorized request
      final authResponse = await http.get(
        Uri.parse('http://127.0.0.1:9878/api/library'),
        headers: {'Authorization': 'Bearer $token'},
      );
      expect(authResponse.statusCode, equals(200));
      expect(authResponse.body, contains('categories'));
    });

    test('returns 401 on /api/download without valid token and serves file when authorized', () async {
      await serverService.start(port: 9879);

      final unauthResponse = await http.get(Uri.parse('http://127.0.0.1:9879/api/download?path=/test.mp3'));
      expect(unauthResponse.statusCode, equals(401));

      final pin = serverService.generatePin();
      final verifyResponse = await http.post(
        Uri.parse('http://127.0.0.1:9879/api/verify_pin'),
        body: {'pin': pin},
      );
      final body = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
      final token = body['token'] as String;

      final authResponse = await http.get(
        Uri.parse('http://127.0.0.1:9879/api/download?path=/test.mp3'),
        headers: {'Authorization': 'Bearer $token'},
      );
      expect(authResponse.statusCode, equals(404)); // File does not exist, but endpoint is reached and auth passed
    });

    test('returns 401 on /api/upload without valid token and handles upload when authorized', () async {
      await serverService.start(port: 9880);

      final unauthResponse = await http.post(
        Uri.parse('http://127.0.0.1:9880/api/upload?targetPath=/tmp/uploaded_test.txt'),
        body: 'Hello World',
      );
      expect(unauthResponse.statusCode, equals(401));

      final pin = serverService.generatePin();
      final verifyResponse = await http.post(
        Uri.parse('http://127.0.0.1:9880/api/verify_pin'),
        body: {'pin': pin},
      );
      final body = jsonDecode(verifyResponse.body) as Map<String, dynamic>;
      final token = body['token'] as String;

      final targetFile = '/tmp/web_server_upload_test_${DateTime.now().millisecondsSinceEpoch}.txt';
      final authResponse = await http.post(
        Uri.parse('http://127.0.0.1:9880/api/upload?targetPath=$targetFile'),
        headers: {'Authorization': 'Bearer $token'},
        body: 'Audiobook test upload data',
      );
      expect(authResponse.statusCode, equals(200));

      final uploadedFile = File(targetFile);
      expect(uploadedFile.existsSync(), isTrue);
      expect(await uploadedFile.readAsString(), equals('Audiobook test upload data'));
      await uploadedFile.delete();
    });

    test('respects onApprovalRequested callback when present', () async {
      await serverService.start(port: 9881);
      final pin = serverService.generatePin();

      // Reject connection
      serverService.onApprovalRequested = (ip) async => false;
      final rejectedResp = await http.post(
        Uri.parse('http://127.0.0.1:9881/api/verify_pin'),
        body: {'pin': pin},
      );
      expect(rejectedResp.statusCode, equals(403));
      expect(rejectedResp.body, contains('rejected'));

      // Approve connection
      serverService.onApprovalRequested = (ip) async => true;
      final approvedResp = await http.post(
        Uri.parse('http://127.0.0.1:9881/api/verify_pin'),
        body: {'pin': pin},
      );
      expect(approvedResp.statusCode, equals(200));
      expect(approvedResp.body, contains('token'));
    });
  });
}
