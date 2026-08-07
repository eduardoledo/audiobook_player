import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../models/path_pattern_rule.dart';
import '../utils/epub_metadata_parser.dart';
import '../utils/pdf_metadata_parser.dart';
import '../models/scan_message.dart';
import '../service_locator.dart';
import 'library_storage.dart';

/// Parsed metadata from directory path relative to the scan root.
/// Intermediate folders without audio only contribute Author/Universe/Saga;
/// the book directory is the one that contains audio (or a multiparte parent).
/// Patterns:
/// - base/Author/BookTitle
/// - base/Author/Saga/BookTitle
/// - base/Author/Universe/Saga/BookTitle
class DirPathMetadata {
  final String author;
  final String? universe;
  final String? saga;
  final String bookTitle;

  const DirPathMetadata({
    required this.author,
    this.universe,
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

  /// Part/disc/era folder under a multiparte book (e.g. CD1, Disc 2, Era 3).
  /// Numbered book titles like "01 - The Final Empire" are NOT parts.
  static bool looksLikePartFolder(String name) {
    final n = name.trim();
    if (RegExp(
      r'^(cd|disc|disk|part|parte|disco|libro|era|eras|acto|act|vol|volume|tomo)[\s._-]*\d+',
      caseSensitive: false,
    ).hasMatch(n)) {
      return true;
    }
    // Bare disc indices only: "1", "01", "12"
    return RegExp(r'^\d{1,3}$').hasMatch(n);
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _isAudioFile(FileSystemEntity entity) {
    return entity is File &&
        _audioExtensions.contains(p.extension(entity.path).toLowerCase());
  }

  static bool _isEbookFile(FileSystemEntity entity) {
    return entity is File &&
        _ebookExtensions.contains(p.extension(entity.path).toLowerCase());
  }

  static Future<List<File>> _listAudioFiles(
    String dirPath, {
    bool recursive = false,
  }) async {
    try {
      final dir = Directory(dirPath);
      final entities = recursive
          ? await dir.list(recursive: true).toList()
          : await dir.list().toList();
      final files = entities.whereType<File>().where(_isAudioFile).toList();
      files.sort((a, b) {
        final relA = p.relative(a.path, from: dirPath);
        final relB = p.relative(b.path, from: dirPath);
        return relA.compareTo(relB);
      });
      return files;
    } catch (_) {
      return [];
    }
  }

  /// True when [dir] has no audio of its own, but ≥2 child folders look like
  /// parts/eras/discs and at least one contains audio.
  static Future<bool> _isMultiPartBookDirectory(
    String dirPath,
    List<Directory> subdirs,
  ) async {
    if (subdirs.length < 2) return false;
    if (!subdirs.every((d) => looksLikePartFolder(p.basename(d.path)))) {
      return false;
    }
    for (final sub in subdirs) {
      final audio = await _listAudioFiles(sub.path, recursive: true);
      if (audio.isNotEmpty) return true;
    }
    return false;
  }

  /// Helper to find book metadata file (prioritizing book.metadata.json over metadata.json)
  static File getBookMetadataFile(String dirPath) {
    final bookMeta = File(p.join(dirPath, 'book.metadata.json'));
    if (bookMeta.existsSync()) return bookMeta;
    final legacyMeta = File(p.join(dirPath, 'metadata.json'));
    if (legacyMeta.existsSync()) return legacyMeta;
    return bookMeta;
  }

  /// Writes author/universe/saga metadata files in parent hierarchy if missing
  static Future<void> ensureParentMetadataFiles({
    required String dirPath,
    required String rootDirectoryPath,
    String? author,
    String? universe,
    String? saga,
  }) async {
    try {
      var current = Directory(dirPath);
      final root = Directory(rootDirectoryPath);

      while (current.path != root.path && current.path.startsWith(root.path)) {
        final currentName = p.basename(current.path);

        if (author != null && currentName.toLowerCase() == author.toLowerCase()) {
          final authorFile = File(p.join(current.path, 'author.metadata.json'));
          if (!await authorFile.exists()) {
            await authorFile.writeAsString(jsonEncode({'name': author, 'type': 'author'}));
          }
        }
        if (universe != null && currentName.toLowerCase() == universe.toLowerCase()) {
          final universeFile = File(p.join(current.path, 'universe.metadata.json'));
          if (!await universeFile.exists()) {
            await universeFile.writeAsString(jsonEncode({'name': universe, 'type': 'universe'}));
          }
        }
        if (saga != null && currentName.toLowerCase() == saga.toLowerCase()) {
          final sagaFile = File(p.join(current.path, 'saga.metadata.json'));
          if (!await sagaFile.exists()) {
            await sagaFile.writeAsString(jsonEncode({'name': saga, 'type': 'saga'}));
          }
          final seriesFile = File(p.join(current.path, 'series.metadata.json'));
          if (!await seriesFile.exists()) {
            await seriesFile.writeAsString(jsonEncode({'name': saga, 'type': 'series'}));
          }
        }

        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}
  }

  /// Reads hierarchical metadata files (author.metadata.json, universe.metadata.json, saga.metadata.json, era.metadata.json) up to scan root.
  static Future<Map<String, dynamic>> readHierarchyMetadata(String dirPath, String rootDirectoryPath) async {
    final result = <String, dynamic>{};
    try {
      var current = Directory(dirPath);
      final root = Directory(rootDirectoryPath);

      while (current.path.startsWith(root.path)) {
        // Author
        final authorFile = File(p.join(current.path, 'author.metadata.json'));
        if (await authorFile.exists()) {
          try {
            final json = jsonDecode(await authorFile.readAsString());
            if (json['name'] != null && !result.containsKey('author')) {
              result['author'] = json['name'].toString();
            }
            if (json['readingOrder'] != null && !result.containsKey('readingOrder')) {
              result['readingOrder'] = json['readingOrder'];
            }
          } catch (_) {}
        }

        // Universe
        final universeFile = File(p.join(current.path, 'universe.metadata.json'));
        if (await universeFile.exists()) {
          try {
            final json = jsonDecode(await universeFile.readAsString());
            if (json['name'] != null && !result.containsKey('universe')) {
              result['universe'] = json['name'].toString();
            }
            if (json['readingOrder'] != null && !result.containsKey('readingOrder')) {
              result['readingOrder'] = json['readingOrder'];
            }
          } catch (_) {}
        }

        // Saga / Series
        final sagaFile = File(p.join(current.path, 'saga.metadata.json'));
        final seriesFile = File(p.join(current.path, 'series.metadata.json'));
        if (await sagaFile.exists() || await seriesFile.exists()) {
          try {
            final targetFile = await sagaFile.exists() ? sagaFile : seriesFile;
            final json = jsonDecode(await targetFile.readAsString());
            if (json['name'] != null && !result.containsKey('saga')) {
              result['saga'] = json['name'].toString();
            }
            if (json['readingOrder'] != null && !result.containsKey('readingOrder')) {
              result['readingOrder'] = json['readingOrder'];
            }
          } catch (_) {}
        }

        // Era
        final eraFile = File(p.join(current.path, 'era.metadata.json'));
        if (await eraFile.exists()) {
          try {
            final json = jsonDecode(await eraFile.readAsString());
            if (json['name'] != null && !result.containsKey('era')) {
              result['era'] = json['name'].toString();
            }
            if (json['readingOrder'] != null && !result.containsKey('readingOrder')) {
              result['readingOrder'] = json['readingOrder'];
            }
          } catch (_) {}
        }

        if (current.path == root.path) break;
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}
    return result;
  }

  /// Parses book [dirPath] relative to scan root for Author/Universe/Saga/Title.
  /// Intermediate folders without audio are metadata only; [dirPath] must be
  /// the audiobook directory (has audio, or multiparte parent).
  static DirPathMetadata? parseDirPath(
    String dirPath,
    String baseDirectoryPath, {
    PathPatternRule? customRule,
  }) {
    final base = p.normalize(baseDirectoryPath);
    final dir = p.normalize(dirPath);
    if (!dir.startsWith(base) || dir == base) return null;
    final relative =
        dir.substring(base.endsWith(p.separator) ? base.length : base.length + 1);
    final segments = p.split(relative).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    if (customRule != null && customRule.roles.isNotEmpty) {
      String author = 'Unknown';
      String? universe;
      String? saga;
      String bookTitle = segments.last;

      for (var i = 0; i < segments.length; i++) {
        final role = i < customRule.roles.length
            ? customRule.roles[i]
            : PathSegmentRole.ignore;
        final val = segments[i];

        switch (role) {
          case PathSegmentRole.author:
            author = val;
            break;
          case PathSegmentRole.universe:
            universe = val;
            break;
          case PathSegmentRole.saga:
            saga = val;
            break;
          case PathSegmentRole.bookTitle:
            bookTitle = val;
            break;
          case PathSegmentRole.part:
          case PathSegmentRole.ignore:
            break;
        }
      }

      return DirPathMetadata(
        author: author,
        universe: _nonEmpty(universe),
        saga: _nonEmpty(saga),
        bookTitle: bookTitle,
      );
    }

    if (segments.length == 1) {
      return DirPathMetadata(author: 'Unknown', bookTitle: segments[0]);
    }
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
    // 4+: Author / Universe / Saga / Title (/ ignored extras)
    return DirPathMetadata(
      author: segments[0],
      universe: segments[1],
      saga: segments[2],
      bookTitle: segments[3],
    );
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

  static const int _largeFileThresholdBytes = 50 * 1024 * 1024; // 50 MiB
  static const int _metadataChunkBytes = 1024 * 1024; // 1 MiB partitions

  /// Reads audio bytes for metadata extraction.
  /// Files ≤50 MiB are loaded whole; larger files are read in partitions
  /// (header, enough to cover a large ID3 tag, and an optional MP4 tail).
  static Future<Uint8List> _readAudioBytesForMetadata(
    File file,
    int fileSize,
  ) async {
    if (fileSize <= _largeFileThresholdBytes) {
      return Uint8List.fromList(await file.readAsBytes());
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      Future<Uint8List> readRange(int start, int length) async {
        await raf.setPosition(start);
        final bytes = await raf.read(length);
        return Uint8List.fromList(bytes);
      }

      // First partition
      var headLen = min(_metadataChunkBytes, fileSize);
      var head = await readRange(0, headLen);

      // If ID3v2 is larger than the first chunk, keep reading partitions
      // until we have the tag plus a small audio header window.
      if (head.length >= 10 &&
          head[0] == 0x49 &&
          head[1] == 0x44 &&
          head[2] == 0x33) {
        final id3Size = ((head[6] & 0x7F) << 21) |
            ((head[7] & 0x7F) << 14) |
            ((head[8] & 0x7F) << 7) |
            (head[9] & 0x7F);
        final needed = min(10 + id3Size + 128 * 1024, fileSize);
        if (needed > head.length) {
          final builder = BytesBuilder(copy: false);
          builder.add(head);
          var pos = head.length;
          while (pos < needed) {
            final n = min(_metadataChunkBytes, needed - pos);
            builder.add(await readRange(pos, n));
            pos += n;
          }
          head = builder.takeBytes();
        }
      }

      final ext = p.extension(file.path).toLowerCase();
      final needsTail =
          ext == '.m4b' || ext == '.m4a' || ext == '.mp4' || ext == '.aac';
      if (!needsTail || fileSize <= head.length) {
        return head;
      }

      // Last partition: MP4/M4B often stores the moov atom at the end.
      final tailLen = min(_metadataChunkBytes, fileSize - head.length);
      final tail = await readRange(fileSize - tailLen, tailLen);
      final combined = BytesBuilder(copy: false);
      combined.add(head);
      combined.add(tail);
      return combined.takeBytes();
    } finally {
      await raf.close();
    }
  }

  static Future<AudioFileMetadata?> getAudioMetadata(File file) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final fileSize = await file.length();
      final bytes = await _readAudioBytesForMetadata(file, fileSize);
      final isPartialRead = fileSize > _largeFileThresholdBytes;

      if (ext == '.mp3') {
        final mp3Duration = _parseMp3Duration(bytes, fileSize);
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

      final meta = AudioMeta(bytes);
      var duration = meta.duration;
      // AudioMeta uses buffer length for CBR duration; correct with real size
      // when we only loaded partitions of a large file.
      if (isPartialRead && meta.bitRate > 0) {
        duration = Duration(
          milliseconds: (fileSize * 8 * 1000) ~/ meta.bitRate,
        );
      }

      return AudioFileMetadata(
        duration: duration,
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
          final pathPatternRules = await storage.getPathPatternRules();

          isolate = await Isolate.spawn(_isolateScan, {
            'path': directoryPath,
            'sendPort': receivePort.sendPort,
            'skipPaths': skipPaths,
            'seriesRules': seriesRules,
            'globalPatterns': globalPatterns,
            'sagaCodes': sagaCodes,
            'knownAuthors': knownAuthors,
            'knownSagas': knownSagas,
            'pathPatternRules': pathPatternRules.map((k, v) => MapEntry(k, v.toJson())),
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
    final Map<String, dynamic> rawRules = args['pathPatternRules'] ?? {};
    final Map<String, PathPatternRule> pathPatternRules = rawRules.map(
      (k, v) => MapEntry(k, PathPatternRule.fromJson(v as Map<String, dynamic>)),
    );

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

    Future<void> emitAudiobook({
      required String bookPath,
      required List<File> audioFiles,
    }) async {
      if (audioFiles.isEmpty || scannedBookPaths.contains(bookPath)) return;
      scannedBookPaths.add(bookPath);

      PathPatternRule? matchedRule;
      for (final entry in pathPatternRules.entries) {
        if (bookPath == entry.key || bookPath.startsWith('${entry.key}${Platform.pathSeparator}')) {
          matchedRule = entry.value;
          break;
        }
      }

      final audiobook = await _loadAudiobook(
        audioFiles: audioFiles,
        dirPath: bookPath,
        baseDirectoryPath: directoryPath,
        seriesRules: seriesRules,
        globalPatterns: globalPatterns,
        sagaCodes: sagaCodes,
        knownAuthors: knownAuthors,
        knownSagas: knownSagas,
        customRule: matchedRule,
      );
      if (audiobook != null) {
        if (audiobook.author != 'Unknown') knownAuthors.add(audiobook.author);
        if (audiobook.series != null) knownSagas.add(audiobook.series!);
        sendPort.send(ScanMessage(
          audiobook: audiobook,
          progress: processedTopDirs / totalTopDirs,
        ));
      }
    }

    Future<void> emitEbooksInDir(
      String dirPath,
      List<FileSystemEntity> entities,
    ) async {
      final ebookFiles =
          entities.whereType<File>().where(_isEbookFile).toList();
      for (final file in ebookFiles) {
        final ebook = await _loadEbook(
          file: file,
          dirPath: dirPath,
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
          sendPort.send(ScanMessage(
            ebook: ebook,
            progress: processedTopDirs / totalTopDirs,
          ));
        }
      }
    }

    /// Walk the tree. Only directories that contain audio are audiobooks.
    /// Exception: multiparte books (CD1/Era1/…) — parent is the book.
    /// Any other folder without audio is only path metadata (Author/Universe/Saga).
    Future<void> scanSubTree(String currentPath) async {
      if (skipPaths.contains(currentPath)) return;
      final dir = Directory(currentPath);
      if (!await dir.exists()) return;

      if (scannedBookPaths.any(
        (bookPath) =>
            bookPath == currentPath || p.isWithin(bookPath, currentPath),
      )) {
        return;
      }

      List<FileSystemEntity> entities = [];
      try {
        entities = await dir.list().toList();
        entities.sort((a, b) => a.path.compareTo(b.path));
      } catch (_) {
        return;
      }

      await emitEbooksInDir(currentPath, entities);

      final directAudio =
          entities.whereType<File>().where(_isAudioFile).toList();
      final subdirs = entities.whereType<Directory>().toList();

      // Rule 0: Presence of book.metadata.json or metadata.json explicitly marks directory as book
      final hasBookMetaFile = File(p.join(currentPath, 'book.metadata.json')).existsSync() ||
          File(p.join(currentPath, 'metadata.json')).existsSync();
      if (hasBookMetaFile) {
        final audioFiles = await _listAudioFiles(currentPath, recursive: true);
        if (audioFiles.isNotEmpty) {
          await emitAudiobook(bookPath: currentPath, audioFiles: audioFiles);
          return;
        }
      }

      // Rule 1: directory with audio files → audiobook (leaf).
      if (directAudio.isNotEmpty) {
        final audioFiles =
            await _listAudioFiles(currentPath, recursive: true);
        await emitAudiobook(bookPath: currentPath, audioFiles: audioFiles);
        return;
      }

      // Rule 2: multiparte — no audio here, but children are parts/eras/discs.
      if (await _isMultiPartBookDirectory(currentPath, subdirs)) {
        final audioFiles =
            await _listAudioFiles(currentPath, recursive: true);
        await emitAudiobook(bookPath: currentPath, audioFiles: audioFiles);
        return;
      }

      // Rule 3: intermediate folder (Author/Universe/Saga/…) — recurse only.
      for (final sub in subdirs) {
        await scanSubTree(sub.path);
      }
    }

    // Root may be a single book, a multiparte book, or a library tree.
    var rootIsBook = false;
    try {
      final baseDir = Directory(directoryPath);
      final rootEntities = await baseDir.list().toList();
      rootEntities.sort((a, b) => a.path.compareTo(b.path));

      await emitEbooksInDir(directoryPath, rootEntities);

      final rootAudio =
          rootEntities.whereType<File>().where(_isAudioFile).toList();
      if (rootAudio.isNotEmpty) {
        final audioFiles =
            await _listAudioFiles(directoryPath, recursive: true);
        await emitAudiobook(bookPath: directoryPath, audioFiles: audioFiles);
        rootIsBook = true;
      } else if (await _isMultiPartBookDirectory(
        directoryPath,
        topLevelDirs,
      )) {
        final audioFiles =
            await _listAudioFiles(directoryPath, recursive: true);
        await emitAudiobook(bookPath: directoryPath, audioFiles: audioFiles);
        rootIsBook = true;
      }
    } catch (_) {}

    // Library roots: walk Author/Universe/Saga folders (metadata only until audio).
    if (!rootIsBook) {
      for (final topDir in topLevelDirs) {
        await scanSubTree(topDir.path);
        processedTopDirs++;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastSendTime > 100 || processedTopDirs == totalTopDirs) {
          sendPort.send(
            ScanMessage(progress: processedTopDirs / totalTopDirs),
          );
          lastSendTime = now;
        }
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
    PathPatternRule? customRule,
  }) async {
    if (audioFiles.isEmpty) return null;

    // Read parent hierarchy metadata files first (author.metadata.json, universe.metadata.json, saga.metadata.json)
    final hierarchyMeta = await readHierarchyMetadata(dirPath, baseDirectoryPath);
    
    final dirPathMetadata = parseDirPath(
      dirPath,
      baseDirectoryPath,
      customRule: customRule,
    );
    String bookTitle = dirPathMetadata?.bookTitle ?? p.basename(dirPath);
    String author = hierarchyMeta['author'] ?? dirPathMetadata?.author ?? 'Unknown';
    String? universe = hierarchyMeta['universe'] ?? _nonEmpty(dirPathMetadata?.universe);
    String? saga = hierarchyMeta['saga'] ?? dirPathMetadata?.saga;
    String? publishYear;
    String? seriesSequence;
    String? narrator;
    
    // Check path for known authors and sagas if not set by hierarchy metadata
    final relativePath = p.relative(dirPath, from: baseDirectoryPath);
    final lowerCaseRelativePath = relativePath.toLowerCase();
    
    if (!hierarchyMeta.containsKey('author')) {
      for (final knownAuthor in knownAuthors) {
        if (lowerCaseRelativePath.contains(knownAuthor.toLowerCase())) {
          author = knownAuthor;
          break;
        }
      }
    }
    if (!hierarchyMeta.containsKey('saga')) {
      for (final knownSaga in knownSagas) {
        if (lowerCaseRelativePath.contains(knownSaga.toLowerCase())) {
          saga = knownSaga;
          break;
        }
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

              if (match.groupNames.contains('universe')) {
                final extractedUniverse = match.namedGroup('universe');
                final normalized = _nonEmpty(extractedUniverse);
                if (normalized != null) {
                  universe = normalized;
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
            if (match.groupNames.contains('universe')) {
               final extractedUniverse = match.namedGroup('universe');
               final normalized = _nonEmpty(extractedUniverse);
               if (normalized != null) universe = normalized;
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

    if (seriesSequence == null && hierarchyMeta['readingOrder'] != null) {
      seriesSequence = hierarchyMeta['readingOrder'].toString();
    }

    return Audiobook(
      path: dirPath,
      title: bookTitle,
      author: author,
      narrator: narrator,
      universe: universe,
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
    String? universe = _nonEmpty(dirPathMetadata?.universe);
    String? saga = dirPathMetadata?.saga;
    String? publishYear;
    String? seriesSequence;
    String? description;
    String? coverPath;
    
    // Check path for known authors and sagas
    final relativePath = p.relative(file.path, from: baseDirectoryPath);
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

              if (match.groupNames.contains('universe')) {
                final normalized = _nonEmpty(match.namedGroup('universe'));
                if (normalized != null) {
                  universe = normalized;
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
            if (match.groupNames.contains('universe')) {
               final extractedUniverse = match.namedGroup('universe');
               final normalized = _nonEmpty(extractedUniverse);
               if (normalized != null) universe = normalized;
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
      universe: universe,
      series: saga,
      seriesSequence: seriesSequence,
      description: description,
      publishYear: publishYear,
      coverPath: coverPath,
      file: file.path,
    );
  }
}
