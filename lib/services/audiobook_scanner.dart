import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../utils/epub_metadata_parser.dart';
import '../utils/pdf_metadata_parser.dart';
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
  static const List<String> _ebookExtensions = ['.epub', '.pdf'];

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
    if (segments.length == 4) {
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

  static Duration? _parseMp3Duration(Uint8List bytes, int fileSize) {
    try {
      int i = 0;
      // Skip ID3v2 tag if present
      if (bytes.length >= 10 &&
          bytes[0] == 0x49 && // 'I'
          bytes[1] == 0x44 && // 'D'
          bytes[2] == 0x33) { // '3'
        final size = ((bytes[6] & 0x7F) << 21) |
                     ((bytes[7] & 0x7F) << 14) |
                     ((bytes[8] & 0x7F) << 7) |
                     (bytes[9] & 0x7F);
        i = 10 + size;
      }

      int mpegOffset = -1;
      for (; i < bytes.length - 4; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
          mpegOffset = i;
          break;
        }
      }

      if (mpegOffset == -1) return null;

      final b1 = bytes[mpegOffset + 1];
      final b2 = bytes[mpegOffset + 2];
      final b3 = bytes[mpegOffset + 3];

      final version = (b1 >> 3) & 0x03;
      final layer = (b1 >> 1) & 0x03;
      final bitrateIdx = (b2 >> 4) & 0x0F;
      final sampleRateIdx = (b2 >> 2) & 0x03;
      final mode = (b3 >> 6) & 0x03;

      if (version == 1 || layer != 1 || bitrateIdx == 0x0F || sampleRateIdx == 0x03) {
        return null;
      }

      int sampleRate = 0;
      if (version == 3) {
        final srTable = [44100, 48000, 32000, 0];
        sampleRate = srTable[sampleRateIdx];
      } else if (version == 2) {
        final srTable = [22050, 24000, 16000, 0];
        sampleRate = srTable[sampleRateIdx];
      } else if (version == 0) {
        final srTable = [11025, 12000, 8000, 0];
        sampleRate = srTable[sampleRateIdx];
      }
      if (sampleRate == 0) return null;

      int bitrate = 0;
      if (version == 3) {
        final brTable = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
        bitrate = brTable[bitrateIdx];
      } else {
        final brTable = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];
        bitrate = brTable[bitrateIdx];
      }
      if (bitrate == 0) return null;

      final isMono = (mode == 3);
      final sideInfoSize = (version == 3)
          ? (isMono ? 17 : 32)
          : (isMono ? 9 : 17);
      final xingOffset = mpegOffset + 4 + sideInfoSize;

      if (xingOffset + 12 <= bytes.length) {
        final isXing = bytes[xingOffset] == 0x58 &&
            bytes[xingOffset + 1] == 0x69 &&
            bytes[xingOffset + 2] == 0x6E &&
            bytes[xingOffset + 3] == 0x67;
        final isInfo = bytes[xingOffset] == 0x49 &&
            bytes[xingOffset + 1] == 0x6E &&
            bytes[xingOffset + 2] == 0x66 &&
            bytes[xingOffset + 3] == 0x6F;

        if (isXing || isInfo) {
          final flags = (bytes[xingOffset + 4] << 24) |
              (bytes[xingOffset + 5] << 16) |
              (bytes[xingOffset + 6] << 8) |
              bytes[xingOffset + 7];
          if ((flags & 0x01) != 0) {
            final frames = (bytes[xingOffset + 8] << 24) |
                (bytes[xingOffset + 9] << 16) |
                (bytes[xingOffset + 10] << 8) |
                bytes[xingOffset + 11];
            final samplesPerFrame = (version == 3) ? 1152 : 576;
            return Duration(milliseconds: (frames * samplesPerFrame * 1000) ~/ sampleRate);
          }
        }
      }

      final audioSize = fileSize - mpegOffset;
      return Duration(milliseconds: (audioSize * 8 * 1000) ~/ (bitrate * 1000));
    } catch (_) {
      return null;
    }
  }

  static Future<AudioFileMetadata?> getAudioMetadata(File file) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final bytes = await file.readAsBytes();

      if (ext == '.mp3') {
        final mp3Duration = _parseMp3Duration(bytes, bytes.length);
        if (mp3Duration != null) {
          return AudioFileMetadata(
            duration: mp3Duration,
            bitRate: 0,
            sampleRate: 0,
            channelCount: 0,
            type: AudioType.mp3,
          );
        }
      }

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
          final knownAuthors = await storage.getAuthors();
          final knownSagas = await storage.getSagas();

          isolate = await Isolate.spawn(_isolateScan, {
            'path': directoryPath,
            'sendPort': receivePort.sendPort,
            'skipPaths': skipPaths,
            'seriesRules': seriesRules,
            'globalPatterns': globalPatterns,
            'sagaCodes': sagaCodes,
            'knownAuthors': knownAuthors,
            'knownSagas': knownSagas,
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
    final Set<String> knownAuthors = args['knownAuthors'] ?? {};
    final Set<String> knownSagas = args['knownSagas'] ?? {};

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

    final Set<String> scannedBookPaths = {};

    Future<void> scanSubTree(String currentPath, String basePath) async {
      if (skipPaths.contains(currentPath)) return;
      final dir = Directory(currentPath);
      if (!await dir.exists()) return;

      // Skip if this path is already recursively handled within a book path we scanned
      if (scannedBookPaths.any((scannedPath) => p.isWithin(scannedPath, currentPath) || scannedPath == currentPath)) {
        return;
      }

      final base = p.normalize(basePath);
      final normalizedCurrent = p.normalize(currentPath);
      String relative = '';
      if (normalizedCurrent.startsWith(base) && normalizedCurrent != base) {
        relative = normalizedCurrent.substring(base.endsWith(p.separator) ? base.length : base.length + 1);
      }
      final segments = p.split(relative).where((s) => s.isNotEmpty).toList();

      if (segments.length == 4) {
        final bookPath = p.dirname(currentPath);
        if (!scannedBookPaths.contains(bookPath)) {
          scannedBookPaths.add(bookPath);
          
          List<File> audioFiles = [];
          try {
            final bookDir = Directory(bookPath);
            final allEntities = await bookDir.list(recursive: true).toList();
            final files = allEntities
                .whereType<File>()
                .where((f) => _audioExtensions.contains(p.extension(f.path).toLowerCase()))
                .toList();
            files.sort((a, b) {
              final relA = p.relative(a.path, from: bookPath);
              final relB = p.relative(b.path, from: bookPath);
              return relA.compareTo(relB);
            });
            audioFiles.addAll(files);
          } catch (_) {}

          if (audioFiles.isNotEmpty) {
            final audiobook = await _loadAudiobook(
              audioFiles: audioFiles,
              dirPath: bookPath,
              baseDirectoryPath: basePath,
              seriesRules: seriesRules,
              globalPatterns: globalPatterns,
              sagaCodes: sagaCodes,
              knownAuthors: knownAuthors,
              knownSagas: knownSagas,
            );
            if (audiobook != null) {
              if (audiobook.author != 'Unknown') knownAuthors.add(audiobook.author);
              if (audiobook.series != null) knownSagas.add(audiobook.series!);
              sendPort.send(ScanMessage(audiobook: audiobook, progress: processedTopDirs / totalTopDirs));
            }
          }
        }
        return;
      }

      List<FileSystemEntity> entities = [];
      try {
        entities = await dir.list().toList();
        entities.sort((a, b) => a.path.compareTo(b.path));
      } catch (_) {
        return;
      }

      var isEbookDirectory = entities.any((entity) =>
          entity is File && _ebookExtensions.contains(p.extension(entity.path).toLowerCase()));

      if (isEbookDirectory) {
        final ebookFiles = entities.whereType<File>().where((f) => _ebookExtensions.contains(p.extension(f.path).toLowerCase())).toList();
        for (var file in ebookFiles) {
          final ebook = await _loadEbook(
            file: file,
            dirPath: currentPath,
            baseDirectoryPath: basePath,
            seriesRules: seriesRules,
            globalPatterns: globalPatterns,
            sagaCodes: sagaCodes,
            knownAuthors: knownAuthors,
            knownSagas: knownSagas,
          );
          if (ebook != null) {
            if (ebook.author != 'Unknown') knownAuthors.add(ebook.author);
            if (ebook.series != null) knownSagas.add(ebook.series!);
            sendPort.send(ScanMessage(ebook: ebook, progress: processedTopDirs / totalTopDirs));
          }
        }
      }

      var isAudioDirectory = entities.any((entity) =>
          entity is File && _audioExtensions.contains(p.extension(entity.path).toLowerCase()));
      
      if (isAudioDirectory) {
        final audioFiles = entities.whereType<File>().where((f) => _audioExtensions.contains(p.extension(f.path).toLowerCase())).toList();
        final audiobook = await _loadAudiobook(
          audioFiles: audioFiles,
          dirPath: currentPath,
          baseDirectoryPath: basePath,
          seriesRules: seriesRules,
          globalPatterns: globalPatterns,
          sagaCodes: sagaCodes,
          knownAuthors: knownAuthors,
          knownSagas: knownSagas,
        );
        if (audiobook != null) {
          if (audiobook.author != 'Unknown') knownAuthors.add(audiobook.author);
          if (audiobook.series != null) knownSagas.add(audiobook.series!);
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
        final audioFiles = rootEntities.whereType<File>().where((f) => _audioExtensions.contains(p.extension(f.path).toLowerCase())).toList();
        final audiobook = await _loadAudiobook(
          audioFiles: audioFiles,
          dirPath: directoryPath,
          baseDirectoryPath: directoryPath,
          seriesRules: seriesRules,
          globalPatterns: globalPatterns,
          sagaCodes: sagaCodes,
          knownAuthors: knownAuthors,
          knownSagas: knownSagas,
        );
        if (audiobook != null) {
          if (audiobook.author != 'Unknown') knownAuthors.add(audiobook.author);
          if (audiobook.series != null) knownSagas.add(audiobook.series!);
          sendPort.send(ScanMessage(audiobook: audiobook, progress: 0.0));
        }
      }

      var isEbookDirectory = rootEntities.any((entity) =>
          entity is File && _ebookExtensions.contains(p.extension(entity.path).toLowerCase()));
      if (isEbookDirectory) {
        final ebookFiles = rootEntities.whereType<File>().where((f) => _ebookExtensions.contains(p.extension(f.path).toLowerCase())).toList();
        for (var file in ebookFiles) {
          final ebook = await _loadEbook(
            file: file,
            dirPath: directoryPath,
            baseDirectoryPath: directoryPath,
            seriesRules: seriesRules,
            globalPatterns: globalPatterns,
            sagaCodes: sagaCodes,
            knownAuthors: knownAuthors,
            knownSagas: knownSagas,
          );
          if (ebook != null) {
            if (ebook.author != 'Unknown') knownAuthors.add(ebook.author);
            if (ebook.series != null) knownSagas.add(ebook.series!);
            sendPort.send(ScanMessage(ebook: ebook, progress: 0.0));
          }
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
  static Future<Audiobook?> _loadAudiobook({
    required List<File> audioFiles,
    required String dirPath,
    required String baseDirectoryPath, 
    Map<String, List<String>>? seriesRules,
    required List<String> globalPatterns,
    required Map<String, String> sagaCodes,
    required Set<String> knownAuthors,
    required Set<String> knownSagas,
  }) async {
    if (audioFiles.isEmpty) return null;

    final dirPathMetadata = parseDirPath(dirPath, baseDirectoryPath);
    String bookTitle = dirPathMetadata?.bookTitle ?? p.basename(dirPath);
    String author = dirPathMetadata?.author ?? 'Unknown';
    String? saga = dirPathMetadata?.saga;
    String? publishYear;
    String? seriesSequence;
    String? narrator;
    
    // Check path for known authors and sagas
    final relativePath = p.relative(dirPath, from: baseDirectoryPath);
    final segments = p.split(relativePath).map((s) => s.trim().toLowerCase()).toList();
    final lowerCaseRelativePath = relativePath.toLowerCase();
    
    for (final knownAuthor in knownAuthors) {
      if (lowerCaseRelativePath.contains(knownAuthor.toLowerCase())) {
        author = knownAuthor;
        break;
      }
    }
    for (final knownSaga in knownSagas) {
      if (lowerCaseRelativePath.contains(knownSaga.toLowerCase())) {
        saga = knownSaga;
        break;
      }
    }

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
      chapters: List.generate(audioFiles.length, (i) {
        final filePath = audioFiles[i].path;
        final parentDir = p.dirname(filePath);
        final grandparentDir = p.dirname(parentDir);
        String? partName;
        if (grandparentDir == dirPath) {
          partName = p.basename(parentDir);
        }
        return Chapter(
          index: i + 1,
          start: 0,
          end: 0,
          duration: 0,
          startFormatted: '00:00:00.000',
          endFormatted: '00:00:00.000',
          durationFormatted: '00:00:00.000',
          title: p.basenameWithoutExtension(filePath),
          displayTitle: partName != null
              ? '$partName - Chapter ${i + 1}'
              : 'Chapter ${i + 1}',
          part: partName,
        );
      }),
    );
  }

  static Future<Ebook?> _loadEbook({
    required File file,
    required String dirPath,
    required String baseDirectoryPath, 
    Map<String, List<String>>? seriesRules,
    required List<String> globalPatterns,
    required Map<String, String> sagaCodes,
    required Set<String> knownAuthors,
    required Set<String> knownSagas,
  }) async {
    final dirPathMetadata = parseDirPath(dirPath, baseDirectoryPath);
    String title = p.basenameWithoutExtension(file.path);
    String author = dirPathMetadata?.author ?? 'Unknown';
    String? saga = dirPathMetadata?.saga;
    String? publishYear;
    String? seriesSequence;
    String? description;
    String? coverPath;
    
    // Check path for known authors and sagas
    final relativePath = p.relative(file.path, from: baseDirectoryPath);
    final segments = p.split(relativePath).map((s) => s.trim().toLowerCase()).toList();
    final lowerCaseRelativePath = relativePath.toLowerCase();
    
    for (final knownAuthor in knownAuthors) {
      if (lowerCaseRelativePath.contains(knownAuthor.toLowerCase())) {
        author = knownAuthor;
        break;
      }
    }
    for (final knownSaga in knownSagas) {
      if (lowerCaseRelativePath.contains(knownSaga.toLowerCase())) {
        saga = knownSaga;
        break;
      }
    }
    
    // First, try extracting embedded metadata based on file extension
    Map<String, String?>? embeddedMeta;
    if (file.path.toLowerCase().endsWith('.epub')) {
      embeddedMeta = await EpubMetadataParser.parse(file);
    } else if (file.path.toLowerCase().endsWith('.pdf')) {
      embeddedMeta = await PdfMetadataParser.parse(file);
    }
    
    bool found = false;

    if (seriesRules != null && seriesRules.isNotEmpty) {
      for (final entry in seriesRules.entries) {
        final seriesName = entry.key;
        for (final patternStr in entry.value) {
          try {
            final regExp = RegExp(patternStr, caseSensitive: false);
            final match = regExp.firstMatch(title);
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
                  title = extractedTitle.trim();
                }
              }
              
              if (match.groupNames.contains('author')) {
                final extractedAuthor = match.namedGroup('author');
                if (extractedAuthor != null && extractedAuthor.isNotEmpty) {
                  author = extractedAuthor.trim();
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
      final relativePath = p.relative(file.path, from: baseDirectoryPath).replaceAll(r'\', '/');
      for (final patternStr in globalPatterns) {
        try {
          final regExp = RegExp(patternStr, caseSensitive: false);
          final match = regExp.firstMatch(relativePath) ?? regExp.firstMatch(title);
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
               if (extractedTitle != null && extractedTitle.isNotEmpty) title = extractedTitle.trim();
            }
            if (match.groupNames.contains('author')) {
               final extractedAuthor = match.namedGroup('author');
               if (extractedAuthor != null && extractedAuthor.isNotEmpty) author = extractedAuthor.trim();
            }
            
            found = true;
            break;
          }
        } catch (_) {}
      }
    }

    // Now, apply embedded metadata, overriding path/regex parsing ONLY if they yield valid data
    if (embeddedMeta != null) {
      if (embeddedMeta['title'] != null && embeddedMeta['title']!.isNotEmpty) title = embeddedMeta['title']!;
      if (embeddedMeta['author'] != null && embeddedMeta['author']!.isNotEmpty) author = embeddedMeta['author']!;
      if (embeddedMeta['description'] != null && embeddedMeta['description']!.isNotEmpty) description = embeddedMeta['description']!;
      if (embeddedMeta['publishYear'] != null && embeddedMeta['publishYear']!.isNotEmpty) publishYear = embeddedMeta['publishYear']!;
      if (embeddedMeta['series'] != null && embeddedMeta['series']!.isNotEmpty) saga = embeddedMeta['series']!;
      if (embeddedMeta['coverPath'] != null && embeddedMeta['coverPath']!.isNotEmpty) coverPath = embeddedMeta['coverPath']!;
    }

    return Ebook(
      path: dirPath,
      title: title,
      author: author,
      series: saga,
      seriesSequence: seriesSequence,
      description: description,
      publishYear: publishYear,
      coverPath: coverPath,
      file: file.path,
    );
  }
}
