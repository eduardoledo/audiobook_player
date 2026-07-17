import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/ebook.dart';

class FetchMessage {
  final List<Ebook> ebooks;
  FetchMessage(this.ebooks);
}

class EbookMetadataFetcher {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static final ReceivePort _receivePort = ReceivePort();

  static Future<void> start({
    required void Function(Ebook) onMetadataFetched,
    required void Function(String path, String status, double progress) onProgress,
    required void Function(String path, String error) onFetchError,
  }) async {
    if (_isolate != null) return;

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
      } else if (message is Map) {
        final type = message['type'] as String?;
        if (type == 'progress') {
          final path = message['path'] as String;
          final status = message['status'] as String;
          final progress = (message['progress'] as num).toDouble();
          onProgress(path, status, progress);
        } else if (type == 'result') {
          final ebook = message['ebook'] as Ebook;
          onMetadataFetched(ebook);
        } else if (type == 'error') {
          final path = message['path'] as String;
          final error = message['error'] as String;
          onFetchError(path, error);
        }
      }
    });

    _isolate = await Isolate.spawn(_isolateWorker, _receivePort.sendPort);
  }

  static void enqueue(List<Ebook> ebooks) {
    if (_sendPort != null) {
      _sendPort!.send(FetchMessage(ebooks));
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendPort?.send(FetchMessage(ebooks));
      });
    }
  }

  static void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  static void clearQueue() {
    if (_sendPort != null) {
      _sendPort!.send('cancel');
    }
  }

  static Future<void> _isolateWorker(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final queue = <Ebook>[];
    bool isProcessing = false;

    receivePort.listen((message) async {
      if (message is FetchMessage) {
        final newBooks = message.ebooks.where((b) => !b.hasMetadataLocally).toList();
        queue.addAll(newBooks);
        
        if (!isProcessing && queue.isNotEmpty) {
          isProcessing = true;
          await _processQueue(queue, sendPort);
          isProcessing = false;
        }
      } else if (message == 'cancel') {
        queue.clear();
      }
    });
  }

  static Future<void> _processQueue(List<Ebook> queue, SendPort sendPort) async {
    while (queue.isNotEmpty) {
      final book = queue.removeAt(0);

      try {
        sendPort.send({
          'type': 'progress',
          'path': book.file,
          'status': 'Searching Google Books API...',
          'progress': 0.3,
        });

        String? coverUrl;
        String? description;
        String? publishYear;

        final query = Uri.encodeComponent('intitle:${book.title} inauthor:${book.author}');
        final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$query&maxResults=1');
        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['items'] != null && data['items'].isNotEmpty) {
            final volumeInfo = data['items'][0]['volumeInfo'];
            description = volumeInfo['description']?.toString();
            
            final rawDate = volumeInfo['publishedDate']?.toString();
            if (rawDate != null && rawDate.length >= 4) {
              publishYear = rawDate.substring(0, 4);
            }

            final imageLinks = volumeInfo['imageLinks'];
            if (imageLinks != null) {
              coverUrl = imageLinks['thumbnail']?.toString()?.replaceAll('http:', 'https:');
            }
          }
        }

        // Try downloading cover if we found one
        String? finalCoverPath = book.coverPath;
        if (coverUrl != null && finalCoverPath == null) {
           sendPort.send({
            'type': 'progress',
            'path': book.file,
            'status': 'Downloading cover...',
            'progress': 0.7,
          });
          
          try {
            final coverResponse = await http.get(Uri.parse(coverUrl)).timeout(const Duration(seconds: 10));
            if (coverResponse.statusCode == 200) {
              final baseDir = p.dirname(book.file);
              final originalFileName = p.basenameWithoutExtension(book.file);
              final newCoverPath = p.join(baseDir, '.$originalFileName' '_cover.jpg');
              await File(newCoverPath).writeAsBytes(coverResponse.bodyBytes);
              finalCoverPath = newCoverPath;
            }
          } catch (e) {
            print('Failed to download ebook cover: $e');
          }
        }

        final updated = book.copyWith(
          description: description ?? book.description,
          publishYear: publishYear ?? book.publishYear,
          coverPath: finalCoverPath ?? book.coverPath,
          hasMetadataLocally: true,
        );

        sendPort.send({
          'type': 'progress',
          'path': book.file,
          'status': 'Done',
          'progress': 1.0,
        });

        sendPort.send({
          'type': 'result',
          'ebook': updated,
        });
      } catch (e) {
        sendPort.send({
          'type': 'error',
          'path': book.file,
          'error': e.toString(),
        });
      }
    }
  }
}
