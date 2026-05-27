import 'dart:io';
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/audiobook.dart';

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

  static String _formatDuration(double seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(3).padLeft(6, '0');
    return '$h:$m:$s';
  }

  /// Extracts audio metadata from a file (duration, bitrate, etc.).
  static Future<AudioFileMetadata?> getAudioMetadata(File file) async {
    try {
      final bytes = await file.readAsBytes();
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

  /// Scans a directory and all subdirectories recursively for audiobooks.
  /// Returns a list of Audiobook objects found.
  static Future<List<Audiobook>> scanDirectory(String directoryPath) async {
    var status = await Permission.manageExternalStorage.request();
    List<FileSystemEntity> entities = [];
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (status.isGranted) {

        final dir = Directory(directoryPath);
        if (await dir.exists()) {
          entities = await dir.list().toList();
        }
    } else {
      throw Exception('Permission denied to access external storage.');
    }
    final results = <Audiobook>[];
    final dir = Directory(directoryPath);

    if (!await dir.exists()) {
      return results;
    }
  
    var isAudioDirectory = entities.any((entity) => entity is File && _audioExtensions.contains(entity.path.toLowerCase().split('.').last));
    if (isAudioDirectory) {
      final audiobook = await _loadAudiobook(entities, directoryPath);
      if (audiobook != null) {
        results.add(audiobook);
      }
    }
    for (final entity in entities) {
      if (entity is File) {
        final ext = entity.path.toLowerCase().split('.').last;
        final fullExt = '.$ext';
        print('fullExt: $fullExt');
        print('entity.path: ${entity.path}');
      }
    }
    
    // for (final entity in entities) {
    //   print('entity: ${entity.runtimeType}');
    //   if (entity is File) {
    //     final ext = entity.path.toLowerCase().split('.').last;
    //     final fullExt = '.$ext';
    //     print('fullExt: $fullExt');
    //     print('entity.path: ${entity.path}');
    //     if (_audioExtensions.contains(fullExt)) {
    //       final audiobook = await _loadAudiobook(entity);
    //       if (audiobook != null) {
    //         results.add(audiobook);
    //       }
    //     }
    //   }
    //   if (entity is Directory) {
    //     final books = await scanDirectory(entity.path);
    //     results.addAll(books);
    //   }
    // }

    return results;
  }

  /// Loads audiobook metadata from a file. Looks for chapters.json in same directory.
  static Future<Audiobook?> _loadAudiobook(List<FileSystemEntity> entities, String baseDirectoryPath) async {
    final audioFiles = entities.whereType<File>().where((f) => _audioExtensions.contains(p.extension(f.path).toLowerCase())).toList();
    if (audioFiles.isEmpty) return null;
    final dir = audioFiles.first.parent;
    final dirPath = dir.path;

    // Get the title from the first audio file metadata or from the directory name
    final dirPathMetadata = parseDirPath(dirPath, baseDirectoryPath);

    // Minimal audiobook without chapters
    return Audiobook(
      // id: '${dirPathMetadata?.author}_${dirPathMetadata?.saga}_${dirPathMetadata?.bookTitle}',
      path: dirPath,
      title: dirPathMetadata?.bookTitle ?? 'Unknown',
      author: dirPathMetadata?.author ?? 'Unknown',
      files: audioFiles.map((file) => file.path).toList(),
      // duration: await audioFiles.map((file) async => (await getAudioMetadata(file))?.durationInSeconds ?? 0).reduce((a, b) async => (await a) + (await b)),
      durationFormatted: await audioFiles.map((file) async => (await getAudioMetadata(file))?.durationInSeconds ?? 0).reduce((a, b) async => (await a) + (await b)).toString(),
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
