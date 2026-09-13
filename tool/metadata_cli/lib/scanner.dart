import 'dart:io';

import 'package:path/path.dart' as p;

import 'hierarchy.dart';
import 'models.dart';
import 'path_metadata.dart';

const _audioExtensions = {'.m4b', '.m4a', '.mp3'};

bool _isAudioFile(FileSystemEntity entity) {
  return entity is File &&
      _audioExtensions.contains(p.extension(entity.path).toLowerCase());
}

Future<List<File>> _listAudioFiles(
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

/// Audio from multiparte folders, ordered by [partOrderFromFolderName].
Future<List<File>> _listMultipartAudioFiles(
  String dirPath,
  List<Directory> subdirs,
) async {
  final parts = List<Directory>.from(subdirs);
  parts.sort((a, b) {
    const unset = 1 << 30;
    final oa = partOrderFromFolderName(p.basename(a.path)) ?? unset;
    final ob = partOrderFromFolderName(p.basename(b.path)) ?? unset;
    final byOrder = oa.compareTo(ob);
    if (byOrder != 0) return byOrder;
    return p
        .basename(a.path)
        .toLowerCase()
        .compareTo(p.basename(b.path).toLowerCase());
  });
  final files = <File>[];
  for (final part in parts) {
    files.addAll(await _listAudioFiles(part.path, recursive: true));
  }
  return files;
}

Future<bool> _isMultiPartBookDirectory(
  String dirPath,
  List<Directory> subdirs,
) async {
  if (subdirs.length < 2) return false;
  // Eras (Mistborn/Era 1, Era 2) are saga subdivisions, not disc parts.
  if (!subdirs.every((d) => looksLikeDiscPartFolder(p.basename(d.path)))) {
    return false;
  }
  for (final sub in subdirs) {
    final audio = await _listAudioFiles(sub.path, recursive: true);
    if (audio.isNotEmpty) return true;
  }
  return false;
}

bool hasBookMetadataFile(String dirPath) {
  return File(p.join(dirPath, 'book.metadata.json')).existsSync() ||
      File(p.join(dirPath, 'metadata.json')).existsSync();
}

Future<ScannedBook> _toScannedBook({
  required String bookPath,
  required String root,
  required List<File> audioFiles,
}) async {
  final pathMeta = parseDirPath(bookPath, root) ??
      PathMetadata(
        author: 'Unknown',
        bookTitle: p.basename(bookPath),
      );
  final hierarchy = await readHierarchyMetadata(bookPath, root);
  return ScannedBook(
    path: bookPath,
    root: root,
    audioFiles: audioFiles.map((f) => f.path).toList(),
    pathMeta: pathMeta,
    hierarchy: hierarchy,
    hasMetadataFile: hasBookMetadataFile(bookPath),
  );
}

/// Walks [root] and returns every detected audiobook directory.
Future<List<ScannedBook>> scanLibrary(String rootPath) async {
  final root = p.normalize(rootPath);
  final baseDir = Directory(root);
  if (!await baseDir.exists()) {
    throw ArgumentError('Directory does not exist: $root');
  }

  final books = <ScannedBook>[];
  final scannedBookPaths = <String>{};

  Future<void> emitAudiobook(String bookPath, List<File> audioFiles) async {
    if (scannedBookPaths.contains(bookPath)) return;
    scannedBookPaths.add(bookPath);
    books.add(await _toScannedBook(
      bookPath: bookPath,
      root: root,
      audioFiles: audioFiles,
    ));
  }

  Future<void> scanSubTree(String currentPath) async {
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

    final directAudio =
        entities.whereType<File>().where(_isAudioFile).toList();
    final subdirs = entities.whereType<Directory>().toList();

    if (hasBookMetadataFile(currentPath)) {
      final audioFiles = await _listAudioFiles(currentPath, recursive: true);
      if (audioFiles.isNotEmpty) {
        await emitAudiobook(currentPath, audioFiles);
        return;
      }
    }

    if (directAudio.isNotEmpty) {
      final audioFiles = await _listAudioFiles(currentPath, recursive: true);
      await emitAudiobook(currentPath, audioFiles);
      return;
    }

    if (await _isMultiPartBookDirectory(currentPath, subdirs)) {
      final audioFiles = await _listMultipartAudioFiles(currentPath, subdirs);
      await emitAudiobook(currentPath, audioFiles);
      return;
    }

    for (final sub in subdirs) {
      await scanSubTree(sub.path);
    }
  }

  var rootIsBook = false;
  try {
    final rootEntities = await baseDir.list().toList();
    rootEntities.sort((a, b) => a.path.compareTo(b.path));
    final topLevelDirs = rootEntities.whereType<Directory>().toList();
    final rootAudio =
        rootEntities.whereType<File>().where(_isAudioFile).toList();

    if (rootAudio.isNotEmpty) {
      final audioFiles = await _listAudioFiles(root, recursive: true);
      await emitAudiobook(root, audioFiles);
      rootIsBook = true;
    } else if (await _isMultiPartBookDirectory(root, topLevelDirs)) {
      final audioFiles = await _listMultipartAudioFiles(root, topLevelDirs);
      await emitAudiobook(root, audioFiles);
      rootIsBook = true;
    }

    if (!rootIsBook) {
      for (final topDir in topLevelDirs) {
        await scanSubTree(topDir.path);
      }
    }
  } catch (e) {
    throw StateError('Failed to scan $root: $e');
  }

  books.sort((a, b) => a.path.compareTo(b.path));
  return books;
}
