import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/audiobook.dart';
import '../models/scan_message.dart';
import '../service_locator.dart';
import 'library_storage.dart';

/// Parsed metadata from directory path.
/// Patterns: "base/Author/BookTitle" or "base/Author/Saga/BookTitle"
class DirPathMetadata {
  final String author;
  final String? saga;
  final String bookTitle;

  const DirPathMetadata({
    required this.author,
    this.saga,
    required this.bookTitle,
  });
}

/// Metadata extracted from an audio file (duration, bitrate, etc.).
class AudioFileMetadata {
  final Duration duration;
  final int bitRate;
  final int sampleRate;
  final int channelCount;
  final int? bitDepth;
  final AudioType type;

  const AudioFileMetadata({
    required this.duration,
    required this.bitRate,
    required this.sampleRate,
    required this.channelCount,
    this.bitDepth,
    required this.type,
  });

  double get durationInSeconds => duration.inMilliseconds / 1000.0;
}

/// Scans directories for audiobooks (m4b files with optional chapters.json).
class AudiobookScanner {
  static const List<String> _audioExtensions = ['.m4b', '.m4a', '.mp3'];

  /// Parses dirPath relative to baseDirectoryPath.
  /// Returns author, saga (optional), bookTitle or null if pattern doesn't match.
  static DirPathMetadata? parseDirPath(String dirPath, String baseDirectoryPath) {
    final base = p.normalize(baseDirectoryPath);
    final dir = p.normalize(dirPath);
    if (!dir.startsWith(base) || dir == base) return null;
    final relative =
        dir.substring(base.endsWith(p.separator) ? base.length : base.length + 1);
    final segments = p.split(relative).where((s) => s.isNotEmpty).toList();
    if (segments.length == 2) {
      return DirPathMetadata(author: segments[0], bookTitle: segments[1]);
    }
    if (segments.length == 3) {
      return DirPathMetadata(
        author: segments[0],
        saga: segments[1],
        bookTitle: segments[2],
      );
    }
    return null;
  }

  static String formatDuration(double seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(3).padLeft(6, '0');
    return '$h:$m:$s';
  }

  static Future<AudioFileMetadata?> getAudioMetadata(File file) async {
    try {
      // Shallow read: Only read the first 512KB to prevent memory exhaustion and slow I/O
      // ID3 tags or M4B/MP4 moov atoms are almost always at the start or end.
      // audio_meta handles missing data gracefully if the moov atom is found early.
      final randomAccessFile = await file.open();
      final bytes = await randomAccessFile.read(512 * 1024);
      await randomAccessFile.close();
      
      final meta = AudioMeta(Uint8List.fromList(bytes));
      return AudioFileMetadata(
        duration: meta.duration,
        bitRate: meta.bitRate,
        sampleRate: meta.sampleRate,
        channelCount: meta.channelCount,
        bitDepth: meta.bitDepth,
        type: meta.type,
      );
    } catch (_) {
      return null;
    }
  }

  /// Scans directories for audiobooks, yielding them progressively.
  Stream<ScanMessage> scanDirectoryStream(String directoryPath, {Set<String> skipPaths = const {}, Map<String, List<String>>? seriesRules}) {
    late StreamController<ScanMessage> controller;
    Isolate? isolate;
    final receivePort = ReceivePort();

    void stopScan() {
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
      if (!controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<ScanMessage>(
      onListen: () async {
        bool hasPermission = true;

        if (Platform.isAndroid || Platform.isIOS) {
          var status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          hasPermission = status.isGranted;
        }

        if (!hasPermission) {
          controller.addError(Exception('Permission denied to access external storage.'));
          stopScan();
          return;
        }

        try {
          final storage = getIt<LibraryStorage>();
          final globalPatterns = await storage.getGlobalPatterns();
          final sagaCodes = await storage.getSagaCodes();

          isolate = await Isolate.spawn(_isolateScan, {
            'path': directoryPath,
            'sendPort': receivePort.sendPort,
            'skipPaths': skipPaths,
            'seriesRules': seriesRules,
            'globalPatterns': globalPatterns,
            'sagaCodes': sagaCodes,
          });

          receivePort.listen((message) {
            if (message == null) {
              stopScan();
            } else if (message is ScanMessage) {
              if (!controller.isClosed) {
                controller.add(message);
              }
            }
          });
        } catch (e) {
          controller.addError(e);
          stopScan();
        }
      },
      onCancel: stopScan,
    );

    return controller.stream;
  }

  static Future<void> _isolateScan(Map<String, dynamic> args) async {
    final String directoryPath = args['path'];
    final SendPort sendPort = args['sendPort'];
    final Set<String> skipPaths = args['skipPaths'] ?? {};
    final Map<String, List<String>>? seriesRules = args['seriesRules'];
    final List<String> globalPatterns = args['globalPatterns'] ?? [];
    final Map<String, String> sagaCodes = args['sagaCodes'] ?? {};

    // Get top-level directories for progress calculation
    List<Directory> topLevelDirs = [];
    try {
      final baseDir = Directory(directoryPath);
      await for (final entity in baseDir.list(recursive: false)) {
        if (entity is Directory && !skipPaths.contains(entity.path)) {
          topLevelDirs.add(entity);
        }
      }
      topLevelDirs.sort((a, b) => a.path.compareTo(b.path));
    } catch (_) {}

    final totalTopDirs = topLevelDirs.isEmpty ? 1 : topLevelDirs.length;
    int processedTopDirs = 0;
    int lastSendTime = DateTime.now().millisecondsSinceEpoch;

    Future<void> scanSubTree(String currentPath, String basePath) async {
      if (skipPaths.contains(currentPath)) return;
      final dir = Directory(currentPath);
      if (!await dir.exists()) return;

      List<FileSystemEntity> entities = [];
      try {
        entities = await dir.list().toList();
        entities.sort((a, b) => a.path.compareTo(b.path));
      } catch (_) {
        return;
      }

      var isAudioDirectory = entities.any((entity) =>
          entity is File && _audioExtensions.contains(p.extension(entity.path).toLowerCase()));
      
      if (isAudioDirectory) {
        final audiobook = await _loadAudiobook(entities, basePath, seriesRules, globalPatterns, sagaCodes);
        if (audiobook != null) {
          sendPort.send(ScanMessage(audiobook: audiobook, progress: processedTopDirs / totalTopDirs));
        }
      }

      for (final entity in entities) {
        if (entity is Directory) {
          await scanSubTree(entity.path, basePath);
        }
      }
    }

    // First scan root dir files (if any)
    try {
      final baseDir = Directory(directoryPath);
      List<FileSystemEntity> rootEntities = await baseDir.list(recursive: false).where((e) => e is File).toList();
      rootEntities.sort((a, b) => a.path.compareTo(b.path));
      var isAudioDirectory = rootEntities.any((entity) =>
          entity is File && _audioExtensions.contains(p.extension(entity.path).toLowerCase()));
      if (isAudioDirectory) {
        final audiobook = await _loadAudiobook(rootEntities, directoryPath, seriesRules, globalPatterns, sagaCodes);
        if (audiobook != null) {
          sendPort.send(ScanMessage(audiobook: audiobook, progress: 0.0));
        }
      }
    } catch (_) {}

    // Then process top level dirs
    for (var topDir in topLevelDirs) {
      await scanSubTree(topDir.path, directoryPath);
      processedTopDirs++;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastSendTime > 100 || processedTopDirs == totalTopDirs) {
        sendPort.send(ScanMessage(progress: processedTopDirs / totalTopDirs));
        lastSendTime = now;
      }
    }

    sendPort.send(ScanMessage(progress: 1.0));
    sendPort.send(null); // Signal completion
  }

  /// Loads audiobook metadata from a file. Looks for chapters.json in same directory.
  static Future<Audiobook?> _loadAudiobook(
      List<FileSystemEntity> entities, 
      String baseDirectoryPath, 
      Map<String, List<String>>? seriesRules,
      List<String> globalPatterns,
      Map<String, String> sagaCodes) async {
    final audioFiles = entities.whereType<File>().where((f) => _audioExtensions.contains(p.extension(f.path).toLowerCase())).toList();
    if (audioFiles.isEmpty) return null;
    final dir = audioFiles.first.parent;
    final dirPath = dir.path;

    final dirPathMetadata = parseDirPath(dirPath, baseDirectoryPath);
    String bookTitle = dirPathMetadata?.bookTitle ?? p.basename(dirPath);
    String author = dirPathMetadata?.author ?? 'Unknown';
    String? saga = dirPathMetadata?.saga;
    String? publishYear;
    String? seriesSequence;
    String? narrator;
    
    bool found = false;

    if (seriesRules != null && seriesRules.isNotEmpty) {
      for (final entry in seriesRules.entries) {
        final seriesName = entry.key;
        for (final patternStr in entry.value) {
          try {
            final regExp = RegExp(patternStr, caseSensitive: false);
            final match = regExp.firstMatch(bookTitle);
            if (match != null) {
              saga = seriesName;
              
              if (match.groupNames.contains('year')) {
                final yearStr = match.namedGroup('year');
                if (yearStr != null && yearStr.isNotEmpty) {
                  publishYear = yearStr.trim();
                }
              }
              
              if (match.groupNames.contains('title')) {
                final extractedTitle = match.namedGroup('title');
                if (extractedTitle != null && extractedTitle.isNotEmpty) {
                  bookTitle = extractedTitle.trim();
                }
              }
              
              if (match.groupNames.contains('author')) {
                final extractedAuthor = match.namedGroup('author');
                if (extractedAuthor != null && extractedAuthor.isNotEmpty) {
                  author = extractedAuthor.trim();
                }
              }

              if (match.groupNames.contains('narrator')) {
                final extractedNarrator = match.namedGroup('narrator');
                if (extractedNarrator != null && extractedNarrator.isNotEmpty) {
                  narrator = extractedNarrator.trim();
                }
              }

              if (match.groupNames.contains('seriesSequence')) {
                final seq = match.namedGroup('seriesSequence');
                if (seq != null && seq.isNotEmpty) {
                  seriesSequence = seq.trim();
                }
              }
              
              found = true;
              break;
            }
          } catch (_) {
            // Invalid regex, ignore
          }
        }
        if (found) break;
      }
    }

    if (!found && globalPatterns.isNotEmpty) {
      final relativePath = p.relative(dirPath, from: baseDirectoryPath).replaceAll(r'\', '/');
      for (final patternStr in globalPatterns) {
        try {
          final regExp = RegExp(patternStr, caseSensitive: false);
          final match = regExp.firstMatch(relativePath) ?? regExp.firstMatch(bookTitle);
          if (match != null) {
            if (match.groupNames.contains('seriesCode')) {
              final code = match.namedGroup('seriesCode');
              if (code != null && code.isNotEmpty) {
                saga = sagaCodes[code] ?? code;
              }
            } else if (match.groupNames.contains('series')) {
               final extractedSeries = match.namedGroup('series');
               if (extractedSeries != null && extractedSeries.isNotEmpty) {
                  saga = extractedSeries.trim();
               }
            }

            if (match.groupNames.contains('seriesSequence')) {
               final seq = match.namedGroup('seriesSequence');
               if (seq != null && seq.isNotEmpty) {
                  seriesSequence = seq.trim();
               }
            }

            if (match.groupNames.contains('year')) {
               final yearStr = match.namedGroup('year');
               if (yearStr != null && yearStr.isNotEmpty) publishYear = yearStr.trim();
            }
            if (match.groupNames.contains('title')) {
               final extractedTitle = match.namedGroup('title');
               if (extractedTitle != null && extractedTitle.isNotEmpty) bookTitle = extractedTitle.trim();
            }
            if (match.groupNames.contains('author')) {
               final extractedAuthor = match.namedGroup('author');
               if (extractedAuthor != null && extractedAuthor.isNotEmpty) author = extractedAuthor.trim();
            }
            if (match.groupNames.contains('narrator')) {
               final extractedNarrator = match.namedGroup('narrator');
               if (extractedNarrator != null && extractedNarrator.isNotEmpty) narrator = extractedNarrator.trim();
            }
            
            found = true;
            break;
          }
        } catch (_) {}
      }
    }

    return Audiobook(
      path: dirPath,
      title: bookTitle,
      author: author,
      narrator: narrator,
      series: saga,
      seriesSequence: seriesSequence,
      publishYear: publishYear,
      files: audioFiles.map((file) => file.path).toList(),
      durationFormatted: '00:00:00.000', // Postponed calculation
      totalChapters: audioFiles.length,
      chapters: [
        Chapter(
          index: 1,
          start: 0,
          end: 0,
          duration: 0,
          startFormatted: '00:00:00.000',
          endFormatted: '00:00:00.000',
          durationFormatted: '00:00:00.000',
          title: '001',
          displayTitle: 'Chapter 1',
        ),
      ],
    );
  }
}
