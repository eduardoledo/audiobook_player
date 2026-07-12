import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/audiobook.dart';
import 'audiobook_scanner.dart';

class FetchMessage {
  final List<Audiobook> audiobooks;
  FetchMessage(this.audiobooks);
}

class MetadataFetcher {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static final ReceivePort _receivePort = ReceivePort();

  static Future<void> start({
    required void Function(Audiobook) onMetadataFetched,
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
          final audiobook = message['audiobook'] as Audiobook;
          onMetadataFetched(audiobook);
        } else if (type == 'error') {
          final path = message['path'] as String;
          final error = message['error'] as String;
          onFetchError(path, error);
        }
      }
    });

    _isolate = await Isolate.spawn(_isolateWorker, _receivePort.sendPort);
  }

  static void enqueue(List<Audiobook> audiobooks) {
    if (_sendPort != null) {
      _sendPort!.send(FetchMessage(audiobooks));
    } else {
      // If isolate hasn't sent its SendPort yet, retry shortly
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendPort?.send(FetchMessage(audiobooks));
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

    final queue = <Audiobook>[];
    bool isProcessing = false;

    receivePort.listen((message) async {
      if (message is FetchMessage) {
        // Add only books that don't have metadata checked locally
        final newBooks = message.audiobooks.where((b) => !b.hasMetadataLocally || b.durationFormatted == '00:00:00.000').toList();
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

  static Map<String, String?> _extractSeries(String title) {
    final match = RegExp(r'\((.*?)(?:,\s*Book\s*(\d+)|(?:,\s*)?#(\d+))\)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      final sName = match.group(1)?.trim();
      final sPos = match.group(2) ?? match.group(3);
      return {'seriesName': sName, 'seriesPosition': sPos};
    }
    return {'seriesName': null, 'seriesPosition': null};
  }

  static Future<void> _processQueue(List<Audiobook> queue, SendPort sendPort) async {
    while (queue.isNotEmpty) {
      final book = queue.removeAt(0);

      try {
        sendPort.send({
          'type': 'progress',
          'path': book.path,
          'status': 'Analyzing audio files...',
          'progress': 0.1,
        });
        final metaFile = File(p.join(book.path, 'metadata.json'));
        final coverPath = p.join(book.path, 'cover.jpg');
        final hasCover = await File(coverPath).exists();

        // Check local metadata.json
        bool hasDurationLocally = false;
        String? localDurationStr;
        Map<String, dynamic> localJson = {};
        if (await metaFile.exists()) {
          final content = await metaFile.readAsString();
          localJson = jsonDecode(content) as Map<String, dynamic>;
          
          if (localJson['durationFormatted'] != null) {
            hasDurationLocally = true;
            localDurationStr = localJson['durationFormatted'] as String?;
          }
        }

        // Calculate duration and chapters if postponed
        String durationStr = localDurationStr ?? book.durationFormatted;
        List<Chapter> newChapters = book.chapters;

        // If no duration locally, or we don't have chapters matching the files count
        if ((durationStr == '00:00:00.000' || !hasDurationLocally || localJson['chapters'] == null) && book.files.isNotEmpty) {
           double cumulativeStart = 0.0;
           List<Chapter> calculatedChapters = [];
           
           for (int i = 0; i < book.files.length; i++) {
             final path = book.files[i];
             double fileDuration = 0.0;
             try {
               final meta = await AudiobookScanner.getAudioMetadata(File(path));
               fileDuration = meta?.durationInSeconds ?? 0.0;
             } catch (_) {}
             
             final parentDir = p.dirname(path);
             final grandparentDir = p.dirname(parentDir);
             String? partName;
             if (grandparentDir == book.path) {
               partName = p.basename(parentDir);
             }
             
             calculatedChapters.add(Chapter(
               index: i,
               start: cumulativeStart,
               end: cumulativeStart + fileDuration,
               duration: fileDuration,
               startFormatted: AudiobookScanner.formatDuration(cumulativeStart),
               endFormatted: AudiobookScanner.formatDuration(cumulativeStart + fileDuration),
               durationFormatted: AudiobookScanner.formatDuration(fileDuration),
               title: p.basenameWithoutExtension(path),
               displayTitle: partName != null
                   ? '$partName - Chapter ${i + 1}'
                   : 'Chapter ${i + 1}',
               part: partName,
             ));
             
             cumulativeStart += fileDuration;
           }
           durationStr = AudiobookScanner.formatDuration(cumulativeStart);
           newChapters = calculatedChapters;
        }

        // 1. If metadata exists, just update duration/chapters if needed and continue
        if (await metaFile.exists() && book.hasMetadataLocally) {
          sendPort.send({
            'type': 'progress',
            'path': book.path,
            'status': 'Updating local metadata database...',
            'progress': 0.9,
          });
          final seriesName = localJson['seriesName'] as String?;
          final seriesPosition = localJson['seriesPosition'] as String?;

          // Only rewrite if we just calculated a new duration or chapters
          if (!hasDurationLocally || localJson['chapters'] == null) {
             localJson['durationFormatted'] = durationStr;
             localJson['chapters'] = newChapters.map((c) => c.toJson()).toList();
             await metaFile.writeAsString(jsonEncode(localJson));
          }

          final updated = book.copyWith(
            description: localJson['description'] as String?,
            publishYear: localJson['publishYear'] as String?,
            subjects: (localJson['subjects'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
            coverPath: hasCover ? coverPath : null,
            series: book.series ?? seriesName,
            title: (seriesPosition != null && !RegExp(r'^\d').hasMatch(book.title)) 
                ? '${seriesPosition.padLeft(2, '0')} - ${book.title}'
                : book.title,
            durationFormatted: durationStr,
            chapters: newChapters,
            hasMetadataLocally: true,
          );
          sendPort.send({
            'type': 'result',
            'audiobook': updated,
          });
          continue;
        }

        // Multi-API Fetching
        String? itunesCoverUrl;
        String? itunesDesc;
        String? itunesYear;
        String? itunesSeries;
        String? itunesSeriesPos;

        // 1. iTunes API
        try {
          sendPort.send({
            'type': 'progress',
            'path': book.path,
            'status': 'Searching iTunes API...',
            'progress': 0.3,
          });
          final query = Uri.encodeComponent('${book.title} ${book.author}');
          final url = Uri.parse('https://itunes.apple.com/search?term=$query&media=audiobook&limit=1');
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['results'] != null && data['results'].isNotEmpty) {
              final result = data['results'][0];
              final rawDesc = result['description']?.toString() ?? '';
              itunesDesc = rawDesc.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ''); // Strip HTML
              itunesYear = result['releaseDate']?.toString().substring(0, 4);
              itunesCoverUrl = result['artworkUrl100']?.toString().replaceAll('100x100bb.jpg', '600x600bb.jpg');
              
              final collectionName = result['collectionName']?.toString() ?? '';
              final extracted = _extractSeries(collectionName);
              itunesSeries = extracted['seriesName'];
              itunesSeriesPos = extracted['seriesPosition'];
            }
          }
        } catch (_) {}

        // 2. Google Books API
        String? googleDesc;
        String? googleYear;
        String? googleSeries;
        String? googleSeriesPos;
        List<String> googleSubjects = [];
        try {
          sendPort.send({
            'type': 'progress',
            'path': book.path,
            'status': 'Searching Google Books...',
            'progress': 0.5,
          });
          final query = Uri.encodeComponent('${book.title} ${book.author}');
          final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$query&maxResults=1');
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['items'] != null && data['items'].isNotEmpty) {
              final vol = data['items'][0]['volumeInfo'];
              googleDesc = vol['description']?.toString();
              final pd = vol['publishedDate']?.toString();
              googleYear = pd != null && pd.length >= 4 ? pd.substring(0, 4) : null;
              
              final title = vol['title']?.toString() ?? '';
              final extracted = _extractSeries(title);
              googleSeries = extracted['seriesName'];
              googleSeriesPos = extracted['seriesPosition'];
              
              if (vol['categories'] != null) {
                googleSubjects = (vol['categories'] as List<dynamic>).map((e) => e.toString()).toList();
              }
            }
          }
        } catch (_) {}

        // 3. OpenLibrary API
        String? olYear;
        String? olSeries;
        String? olSeriesPos;
        List<String> olSubjects = [];
        String? olCoverI;
        try {
          sendPort.send({
            'type': 'progress',
            'path': book.path,
            'status': 'Searching OpenLibrary...',
            'progress': 0.7,
          });
          final query = Uri.encodeComponent('${book.title} ${book.author}');
          final url = Uri.parse('https://openlibrary.org/search.json?q=$query&limit=1');
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['docs'] != null && data['docs'].isNotEmpty) {
              final doc = data['docs'][0];
              olYear = doc['first_publish_year']?.toString();
              olSubjects = (doc['subject'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              olSeries = (doc['series_name'] as List<dynamic>?)?.firstOrNull?.toString();
              olSeriesPos = (doc['series_position'] as List<dynamic>?)?.firstOrNull?.toString();
              olCoverI = doc['cover_i']?.toString();
            }
          }
        } catch (_) {}

        // Merge Data
        final bestDesc = itunesDesc ?? googleDesc;
        final bestYear = itunesYear ?? googleYear ?? olYear;
        final bestSubjects = olSubjects.isNotEmpty ? olSubjects : googleSubjects;
        final bestSeries = olSeries ?? itunesSeries ?? googleSeries;
        final bestSeriesPos = olSeriesPos ?? itunesSeriesPos ?? googleSeriesPos;
        
        // Cover Logic
        String? localCoverPath = hasCover ? coverPath : null;
        String? bestCoverUrl = itunesCoverUrl;
        if (!hasCover) {
          if (bestCoverUrl == null && olCoverI != null) {
             bestCoverUrl = 'https://covers.openlibrary.org/b/id/$olCoverI-L.jpg';
          }
          if (bestCoverUrl != null) {
            try {
              sendPort.send({
                'type': 'progress',
                'path': book.path,
                'status': 'Downloading cover artwork...',
                'progress': 0.85,
              });
              final coverResp = await http.get(Uri.parse(bestCoverUrl)).timeout(const Duration(seconds: 15));
              if (coverResp.statusCode == 200) {
                final coverFile = File(coverPath);
                await coverFile.writeAsBytes(coverResp.bodyBytes);
                localCoverPath = coverFile.path;
              }
            } catch (_) {}
          }
        }

        final isEmpty = bestDesc == null && bestYear == null && bestSeries == null && bestCoverUrl == null;
        sendPort.send({
          'type': 'progress',
          'path': book.path,
          'status': 'Saving local metadata...',
          'progress': 0.95,
        });
        if (isEmpty && !hasCover) {
           await metaFile.writeAsString(jsonEncode({'durationFormatted': durationStr, 'chapters': newChapters.map((c) => c.toJson()).toList()}));
           sendPort.send({
             'type': 'result',
             'audiobook': book.copyWith(hasMetadataLocally: true, durationFormatted: durationStr, chapters: newChapters),
           });
        } else {
           // Save metadata locally
           final newJson = {
             'description': bestDesc,
             'publishYear': bestYear,
             'subjects': bestSubjects,
             'seriesName': bestSeries,
             'seriesPosition': bestSeriesPos,
             'durationFormatted': durationStr,
             'chapters': newChapters.map((c) => c.toJson()).toList(),
           };
           await metaFile.writeAsString(jsonEncode(newJson));

           // "Intentar corrección": overwrite book.series with bestSeries if found
           final updatedSeries = bestSeries ?? book.series;

           final updated = book.copyWith(
             description: bestDesc,
             publishYear: bestYear,
             subjects: bestSubjects,
             coverPath: localCoverPath,
             series: updatedSeries,
             title: (bestSeriesPos != null && !RegExp(r'^\d').hasMatch(book.title)) 
                 ? '${bestSeriesPos.padLeft(2, '0')} - ${book.title}'
                 : book.title,
             durationFormatted: durationStr,
             chapters: newChapters,
             hasMetadataLocally: true,
           );
           sendPort.send({
             'type': 'result',
             'audiobook': updated,
           });
        }
      } catch (e, stack) {
        debugPrint("MetadataFetcher error: $e");
        debugPrint(stack.toString());
        sendPort.send({
          'type': 'error',
          'path': book.path,
          'error': e.toString(),
        });
      }
      
      // Delay to respect OpenLibrary's rate limit policies
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
