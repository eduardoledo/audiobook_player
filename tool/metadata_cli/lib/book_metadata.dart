import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'path_metadata.dart';

export 'duration_estimate.dart' show estimateDurationFormatted;

File bookMetadataFile(String dirPath) {
  final bookMeta = File(p.join(dirPath, 'book.metadata.json'));
  if (bookMeta.existsSync()) return bookMeta;
  final legacyMeta = File(p.join(dirPath, 'metadata.json'));
  if (legacyMeta.existsSync()) return legacyMeta;
  return bookMeta;
}

File preferredBookMetadataFile(String dirPath) =>
    File(p.join(dirPath, 'book.metadata.json'));

BookMetadata? loadBookMetadata(String dirPath) {
  final file = bookMetadataFile(dirPath);
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return bookMetadataFromJson(json);
  } catch (_) {
    return null;
  }
}

BookMetadata bookMetadataFromJson(Map<String, dynamic> json) {
  final blankKeys = <String>{};

  String? readClearable(String key, [List<String> aliases = const []]) {
    final keys = [key, ...aliases];
    for (final k in keys) {
      if (!json.containsKey(k)) continue;
      final raw = json[k];
      if (raw == null) {
        blankKeys.add(key);
        return null;
      }
      final text = raw.toString().trim();
      if (text.isEmpty) {
        blankKeys.add(key);
        return null;
      }
      return text;
    }
    return null;
  }

  final seriesName = readClearable('seriesName', ['series', 'album']);
  final seriesPosition = readClearable('seriesPosition', ['seriesSequence']);
  final universeOrder = readClearable('universeOrder', ['universePosition']);
  final universe = readClearable('universe');
  final narrator = readClearable('narrator');
  final partOf = readClearable('partOf', ['parentTitle', 'bookTitle']);
  final partName = readClearable('partName', ['part', 'disc']);

  final subjectsRaw = json['subjects'];
  final subjects = subjectsRaw is List
      ? subjectsRaw.map((e) => e.toString()).toList()
      : <String>[];

  final chaptersRaw = json['chapters'];
  final chapters = chaptersRaw is List ? List<dynamic>.from(chaptersRaw) : [];

  final partsRaw = json['parts'];
  final parts = <BookPart>[];
  if (partsRaw is List) {
    for (final item in partsRaw) {
      BookPart? part;
      if (item is Map<String, dynamic>) {
        part = BookPart.fromJson(item);
      } else if (item is Map) {
        part = BookPart.fromJson(Map<String, dynamic>.from(item));
      }
      if (part == null) continue;
      if (part.order == null) {
        final inferred = partOrderFromFolderName(part.name) ??
            (part.path.isNotEmpty
                ? partOrderFromFolderName(p.basename(part.path))
                : null);
        if (inferred != null) {
          part = part.copyWith(order: inferred);
        }
      }
      parts.add(part);
    }
  }
  parts.sort(BookMetadata.comparePartsByOrder);

  final duration = nonEmpty(json['durationFormatted']?.toString()) ??
      nonEmpty((json['audio'] as Map?)?['durationFormatted']?.toString()) ??
      '00:00:00.000';

  final entryType = BookMetadata.normalizeEntryType(
    json['entryType']?.toString() ?? json['type']?.toString(),
  );

  return BookMetadata(
    title: json['title']?.toString() ?? '',
    author: json['author']?.toString() ?? 'Unknown',
    narrator: narrator,
    universe: universe,
    seriesName: seriesName,
    seriesPosition: seriesPosition,
    universeOrder: universeOrder,
    era: nonEmpty(json['era']?.toString()),
    readingOrderKey: _readingOrderKeyFromJson(json['readingOrderKey']),
    description: nonEmpty(json['description']?.toString()),
    publishYear: nonEmpty(json['publishYear']?.toString()),
    subjects: subjects,
    durationFormatted: duration,
    chapters: chapters,
    parts: parts,
    entryType: entryType,
    partOf: partOf,
    partName: partName,
    blankKeys: blankKeys,
  );
}

List<double> _readingOrderKeyFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <double>[];
  for (final item in raw) {
    if (item is num) {
      out.add(item.toDouble());
    } else {
      final parsed = double.tryParse(item.toString());
      if (parsed != null) out.add(parsed);
    }
  }
  return out;
}

/// If [meta] is a part and [title] was filled with the part folder name
/// (e.g. CD1 / Disc 2), move that into [partName] and set title/[partOf]
/// to the parent book directory name.
void adjustPartTitles(BookMetadata meta, {required String bookPath}) {
  if (!meta.isPart) return;

  final folderName = p.basename(bookPath);
  final parentName = p.basename(p.dirname(bookPath));

  final titleIsPartLabel = meta.title.isNotEmpty &&
      (looksLikePartFolder(meta.title) ||
          meta.title == folderName ||
          (meta.partName != null &&
              meta.partName!.isNotEmpty &&
              meta.title.toLowerCase() == meta.partName!.toLowerCase()));

  if ((meta.partName == null || meta.partName!.trim().isEmpty) &&
      !meta.blankKeys.contains('partName')) {
    if (titleIsPartLabel) {
      meta.setClearable('partName', meta.title);
    } else if (looksLikePartFolder(folderName)) {
      meta.setClearable('partName', folderName);
    }
  }

  final parentLooksLikeBook =
      parentName.isNotEmpty && !looksLikePartFolder(parentName);

  if ((meta.partOf == null || meta.partOf!.trim().isEmpty) &&
      !meta.blankKeys.contains('partOf') &&
      parentLooksLikeBook) {
    meta.setClearable('partOf', parentName);
  }

  if (titleIsPartLabel) {
    final bookTitle = (meta.partOf != null && meta.partOf!.trim().isNotEmpty)
        ? meta.partOf!.trim()
        : (parentLooksLikeBook ? parentName : null);
    if (bookTitle != null && bookTitle.isNotEmpty) {
      meta.title = bookTitle;
    }
  }
}

/// Builds metadata from path/hierarchy, then merges existing JSON (existing wins
/// for non-empty fields unless [preferPath] is true for structural fields).
BookMetadata buildFromScan(
  ScannedBook book, {
  BookMetadata? existing,
  bool preferPath = false,
}) {
  final pathPos = book.pathMeta.seriesPosition;
  final readingOrder = book.hierarchy['readingOrder']?.toString();
  final folderName = p.basename(book.path);
  final looksPart = looksLikePartFolder(folderName);
  final parentTitle = p.basename(p.dirname(book.path));

  final yearFromPath = book.pathMeta.publishYear ??
      (looksPart ? publishYearFromPath(parentTitle) : null);
  final narratorFromPathMeta = book.pathMeta.narrator ??
      (looksPart
          ? (narratorFromPath(parentTitle) ??
              narratorFromPath(
                yearFromPath != null
                    ? stripPublishYearFromTitle(parentTitle)
                    : parentTitle,
              ))
          : null);
  final titleFromPath = looksPart
      ? () {
          var cleaned = yearFromPath != null
              ? stripPublishYearFromTitle(parentTitle)
              : parentTitle;
          if (narratorFromPathMeta != null) {
            cleaned = stripNarratorFromTitle(cleaned);
          }
          return cleaned.isNotEmpty ? cleaned : parentTitle;
        }()
      : book.pathMeta.bookTitle;

  var meta = BookMetadata(
    title: titleFromPath,
    author: book.author,
    universe: book.universe,
    seriesName: book.series,
    seriesPosition: pathPos ?? nonEmpty(readingOrder),
    universeOrder: book.pathMeta.universeOrder,
    era: book.era,
    readingOrderKey: book.pathMeta.readingOrderKey,
    publishYear: yearFromPath,
    narrator: narratorFromPathMeta,
    entryType: looksPart ? 'part' : 'book',
    partName: looksPart ? folderName : null,
    partOf: looksPart ? titleFromPath : null,
  );

  if (existing != null) {
    meta = mergeMetadata(
      base: preferPath ? meta : existing,
      overlay: preferPath ? existing : meta,
      overlayFillsOnly: !preferPath,
    );
    // Always keep chapters from existing unless empty.
    if (existing.chapters.isNotEmpty) {
      meta.chapters = List<dynamic>.from(existing.chapters);
    }
    if (existing.durationFormatted != '00:00:00.000') {
      meta.durationFormatted = existing.durationFormatted;
    }
    if (existing.parts.isNotEmpty && meta.parts.isEmpty) {
      meta.parts = List<BookPart>.from(existing.parts);
    }
  }

  if (meta.title.isEmpty) {
    meta.title = titleFromPath;
  }
  if (meta.author.isEmpty) {
    meta.author = book.author;
  }
  if ((meta.publishYear == null || meta.publishYear!.isEmpty) &&
      yearFromPath != null) {
    meta.publishYear = yearFromPath;
  }
  if ((meta.narrator == null || meta.narrator!.isEmpty) &&
      narratorFromPathMeta != null) {
    meta.narrator = narratorFromPathMeta;
  }
  if ((meta.era == null || meta.era!.isEmpty) && book.era != null) {
    meta.era = book.era;
  }
  if ((meta.universeOrder == null || meta.universeOrder!.isEmpty) &&
      book.pathMeta.universeOrder != null) {
    meta.universeOrder = book.pathMeta.universeOrder;
  }
  if (meta.readingOrderKey.isEmpty &&
      book.pathMeta.readingOrderKey.isNotEmpty) {
    meta.readingOrderKey = List<double>.from(book.pathMeta.readingOrderKey);
  }

  if (meta.isPart) {
    adjustPartTitles(meta, bookPath: book.path);
  }

  return meta;
}

/// Merges [overlay] into [base]. When [overlayFillsOnly], overlay only fills
/// empty base fields; otherwise overlay non-empty values replace base.
BookMetadata mergeMetadata({
  required BookMetadata base,
  required BookMetadata overlay,
  bool overlayFillsOnly = true,
}) {
  String? pick(String? baseVal, String? overlayVal) {
    if (overlayFillsOnly) {
      if (baseVal != null && baseVal.isNotEmpty) return baseVal;
      return overlayVal;
    }
    if (overlayVal != null && overlayVal.isNotEmpty) return overlayVal;
    return baseVal;
  }

  final result = base.copy();
  result.title = overlayFillsOnly
      ? (base.title.isNotEmpty ? base.title : overlay.title)
      : (overlay.title.isNotEmpty ? overlay.title : base.title);
  result.author = overlayFillsOnly
      ? (base.author.isNotEmpty ? base.author : overlay.author)
      : (overlay.author.isNotEmpty ? overlay.author : base.author);
  result.description = pick(base.description, overlay.description);
  result.publishYear = pick(base.publishYear, overlay.publishYear);
  result.era = pick(base.era, overlay.era);
  result.universeOrder = pick(base.universeOrder, overlay.universeOrder);
  if (overlayFillsOnly) {
    if (result.readingOrderKey.isEmpty && overlay.readingOrderKey.isNotEmpty) {
      result.readingOrderKey = List<double>.from(overlay.readingOrderKey);
    }
  } else if (overlay.readingOrderKey.isNotEmpty) {
    result.readingOrderKey = List<double>.from(overlay.readingOrderKey);
  }

  // Prefer an explicit existing entryType over path guess when filling only.
  if (overlayFillsOnly) {
    result.entryType = base.entryType;
  } else {
    result.entryType = overlay.entryType;
  }

  for (final key in BookMetadata.clearableKeys) {
    if (base.blankKeys.contains(key)) {
      result.clearField(key);
      continue;
    }
    if (!overlayFillsOnly && overlay.blankKeys.contains(key)) {
      result.clearField(key);
      continue;
    }
    switch (key) {
      case 'universe':
        result.universe = pick(base.universe, overlay.universe);
        result.blankKeys.remove('universe');
        break;
      case 'seriesName':
        result.seriesName = pick(base.seriesName, overlay.seriesName);
        result.blankKeys.remove('seriesName');
        break;
      case 'seriesPosition':
        result.seriesPosition =
            pick(base.seriesPosition, overlay.seriesPosition);
        result.blankKeys.remove('seriesPosition');
        break;
      case 'universeOrder':
        result.universeOrder =
            pick(base.universeOrder, overlay.universeOrder);
        result.blankKeys.remove('universeOrder');
        break;
      case 'narrator':
        result.narrator = pick(base.narrator, overlay.narrator);
        result.blankKeys.remove('narrator');
        break;
      case 'partOf':
        result.partOf = pick(base.partOf, overlay.partOf);
        result.blankKeys.remove('partOf');
        break;
      case 'partName':
        result.partName = pick(base.partName, overlay.partName);
        result.blankKeys.remove('partName');
        break;
    }
  }

  if (overlayFillsOnly) {
    if (result.subjects.isEmpty && overlay.subjects.isNotEmpty) {
      result.subjects = List<String>.from(overlay.subjects);
    }
  } else if (overlay.subjects.isNotEmpty) {
    result.subjects = List<String>.from(overlay.subjects);
  }

  if (overlay.durationFormatted != '00:00:00.000') {
    if (!overlayFillsOnly || result.durationFormatted == '00:00:00.000') {
      result.durationFormatted = overlay.durationFormatted;
    }
  }
  if (overlay.chapters.isNotEmpty) {
    if (!overlayFillsOnly || result.chapters.isEmpty) {
      result.chapters = List<dynamic>.from(overlay.chapters);
    }
  }
  if (overlayFillsOnly) {
    if (result.parts.isEmpty && overlay.parts.isNotEmpty) {
      result.parts = List<BookPart>.from(overlay.parts);
    }
  } else if (overlay.parts.isNotEmpty) {
    result.parts = List<BookPart>.from(overlay.parts);
  }

  return result;
}

/// Applies online enrichment only into empty fields.
BookMetadata applyOnlineEnrichment(
  BookMetadata meta,
  OnlineEnrichment online,
) {
  final overlay = BookMetadata(
    title: meta.title,
    author: meta.author,
    seriesName: meta.blankKeys.contains('seriesName') ? null : online.seriesName,
    seriesPosition: meta.blankKeys.contains('seriesPosition')
        ? null
        : online.seriesPosition,
    description: online.description,
    publishYear: online.publishYear,
    subjects: online.subjects,
  );
  final merged = mergeMetadata(base: meta, overlay: overlay, overlayFillsOnly: true);
  // Preserve intentional blanks after merge.
  for (final key in meta.blankKeys) {
    merged.clearField(key);
  }
  return merged;
}

Future<void> saveBookMetadata(String dirPath, BookMetadata meta) async {
  // Only persist full books; parts are merged into the parent book.
  final toSave = meta.copy()..entryType = 'book';
  final file = preferredBookMetadataFile(dirPath);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(toSave.toJson())}\n');
}

Future<void> deleteBookMetadataFiles(String dirPath) async {
  for (final name in ['book.metadata.json', 'metadata.json']) {
    final file = File(p.join(dirPath, name));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Sidecar filenames written by metadata_cli / the app under library dirs.
const List<String> libraryMetadataFileNames = [
  'book.metadata.json',
  'metadata.json',
  'author.metadata.json',
  'universe.metadata.json',
  'saga.metadata.json',
  'series.metadata.json',
  'era.metadata.json',
  'chapters.json',
];

/// Finds metadata sidecars under [rootPath] (optionally including `cover.jpg`).
Future<List<File>> findLibraryMetadataFiles(
  String rootPath, {
  bool includeCovers = false,
}) async {
  final root = Directory(p.normalize(rootPath));
  if (!await root.exists()) {
    throw ArgumentError('Directory does not exist: $rootPath');
  }

  final names = <String>{
    ...libraryMetadataFileNames,
    if (includeCovers) 'cover.jpg',
  };
  final found = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (names.contains(p.basename(entity.path))) {
      found.add(entity);
    }
  }
  found.sort((a, b) => a.path.compareTo(b.path));
  return found;
}

/// Deletes metadata sidecars under [rootPath]. Returns deleted paths.
Future<List<String>> clearLibraryMetadata(
  String rootPath, {
  bool includeCovers = false,
}) async {
  final files = await findLibraryMetadataFiles(
    rootPath,
    includeCovers: includeCovers,
  );
  final deleted = <String>[];
  for (final file in files) {
    try {
      await file.delete();
      deleted.add(file.path);
    } catch (_) {}
  }
  return deleted;
}

/// Resolves the parent audiobook directory for a part folder.
Future<String?> resolveParentBookPath({
  required ScannedBook partBook,
  required BookMetadata partMeta,
  required List<ScannedBook> libraryBooks,
}) async {
  final parentDir = Directory(partBook.path).parent.path;

  // 1) Explicit parent directory that already looks like / is a book.
  if (p.equals(parentDir, partBook.root) == false) {
    final parentHasMeta =
        File(p.join(parentDir, 'book.metadata.json')).existsSync() ||
            File(p.join(parentDir, 'metadata.json')).existsSync();
    if (parentHasMeta || await _dirLooksLikeBook(parentDir)) {
      return parentDir;
    }
  }

  // 2) Match partOf title against library books (same author preferred).
  final wantTitle = partMeta.partOf?.trim();
  if (wantTitle != null && wantTitle.isNotEmpty) {
    final wantAuthor = partMeta.author.trim().toLowerCase();
    ScannedBook? best;
    for (final b in libraryBooks) {
      if (p.equals(b.path, partBook.path)) continue;
      final existing = loadBookMetadata(b.path);
      final title = (existing?.title ?? b.pathMeta.bookTitle).trim();
      if (title.toLowerCase() != wantTitle.toLowerCase()) continue;
      if (existing?.isPart == true) continue;
      final author = (existing?.author ?? b.author).trim().toLowerCase();
      if (author == wantAuthor) return b.path;
      best ??= b;
    }
    if (best != null) return best.path;
  }

  // 3) Fall back to immediate parent directory.
  if (!p.equals(parentDir, partBook.path) &&
      !p.equals(parentDir, partBook.root)) {
    return parentDir;
  }
  return null;
}

Future<bool> _dirLooksLikeBook(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return false;
  try {
    final entities = await dir.list().toList();
    final hasAudio = entities.any(
      (e) =>
          e is File &&
          {'.m4b', '.m4a', '.mp3'}.contains(p.extension(e.path).toLowerCase()),
    );
    if (hasAudio) return true;
    final subdirs = entities.whereType<Directory>().toList();
    if (subdirs.length >= 2 &&
        subdirs.every((d) => looksLikePartFolder(p.basename(d.path)))) {
      return true;
    }
  } catch (_) {}
  return false;
}

/// Merges [partMeta]/[partBook] into the parent book's metadata and removes
/// any metadata file on the part folder.
Future<String> savePartIntoParentBook({
  required ScannedBook partBook,
  required BookMetadata partMeta,
  required List<ScannedBook> libraryBooks,
}) async {
  final parentPath = await resolveParentBookPath(
    partBook: partBook,
    partMeta: partMeta,
    libraryBooks: libraryBooks,
  );
  if (parentPath == null) {
    throw StateError(
      'No se pudo determinar el libro padre para la parte ${partBook.path}. '
      'Indicá partOf (título del libro).',
    );
  }

  final existingParent = loadBookMetadata(parentPath);
  late final BookMetadata parentMeta;
  if (existingParent != null) {
    parentMeta = existingParent.copy()..entryType = 'book';
  } else {
    final pathMeta = parseDirPath(parentPath, partBook.root);
    parentMeta = BookMetadata(
      title: partMeta.partOf?.trim().isNotEmpty == true
          ? partMeta.partOf!.trim()
          : (pathMeta?.bookTitle ?? p.basename(parentPath)),
      author: (pathMeta?.author != null &&
              pathMeta!.author.isNotEmpty &&
              pathMeta.author != 'Unknown')
          ? pathMeta.author
          : (partMeta.author.isNotEmpty ? partMeta.author : 'Unknown'),
      universe: pathMeta?.universe,
      seriesName: pathMeta?.saga,
      narrator: partMeta.blankKeys.contains('narrator')
          ? null
          : partMeta.narrator,
      entryType: 'book',
    );
  }

  // Prefer parent identity; fill gaps from part when useful.
  if (parentMeta.title.isEmpty &&
      partMeta.partOf != null &&
      partMeta.partOf!.isNotEmpty) {
    parentMeta.title = partMeta.partOf!;
  }
  if ((parentMeta.narrator == null || parentMeta.narrator!.isEmpty) &&
      partMeta.narrator != null &&
      partMeta.narrator!.isNotEmpty &&
      !partMeta.blankKeys.contains('narrator')) {
    parentMeta.narrator = partMeta.narrator;
  }

  final partName = (partMeta.partName?.trim().isNotEmpty == true)
      ? partMeta.partName!.trim()
      : (partMeta.title.trim().isNotEmpty
          ? partMeta.title.trim()
          : p.basename(partBook.path));

  parentMeta.upsertPart(
    BookPart(
      name: partName,
      path: partBook.path,
      durationFormatted: partMeta.durationFormatted,
      audioFiles: List<String>.from(partBook.audioFiles),
      order: partOrderFromFolderName(partName) ??
          partOrderFromFolderName(p.basename(partBook.path)),
    ),
  );

  // Refresh total duration from parts when parent duration is empty.
  if (parentMeta.durationFormatted == '00:00:00.000') {
    parentMeta.durationFormatted =
        _sumDurations(parentMeta.parts.map((p) => p.durationFormatted));
  }

  await saveBookMetadata(parentPath, parentMeta);
  await deleteBookMetadataFiles(partBook.path);
  return parentPath;
}

String _sumDurations(Iterable<String?> values) {
  double total = 0;
  var any = false;
  for (final raw in values) {
    if (raw == null || raw.isEmpty || raw == '00:00:00.000') continue;
    final parts = raw.split(':');
    if (parts.length != 3) continue;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    total += h * 3600 + m * 60 + s;
    any = true;
  }
  if (!any || total <= 0) return '00:00:00.000';
  return formatDuration(total);
}

