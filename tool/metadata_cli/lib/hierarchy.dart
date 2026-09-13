import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'path_metadata.dart';

/// Reads hierarchical metadata sidecars walking up from [dirPath] to [rootDirectoryPath].
Future<Map<String, dynamic>> readHierarchyMetadata(
  String dirPath,
  String rootDirectoryPath,
) async {
  final result = <String, dynamic>{};
  try {
    var current = Directory(dirPath);
    final root = Directory(rootDirectoryPath);

    while (current.path.startsWith(root.path)) {
      Future<void> readNamed(String fileName, String key) async {
        final file = File(p.join(current.path, fileName));
        if (!await file.exists()) return;
        try {
          final json = jsonDecode(await file.readAsString());
          if (json['name'] != null && !result.containsKey(key)) {
            result[key] = json['name'].toString();
          }
          if (json['readingOrder'] != null &&
              !result.containsKey('readingOrder')) {
            result['readingOrder'] = json['readingOrder'];
          }
        } catch (_) {}
      }

      await readNamed('author.metadata.json', 'author');
      await readNamed('universe.metadata.json', 'universe');

      final sagaFile = File(p.join(current.path, 'saga.metadata.json'));
      final seriesFile = File(p.join(current.path, 'series.metadata.json'));
      if (await sagaFile.exists() || await seriesFile.exists()) {
        try {
          final targetFile =
              await sagaFile.exists() ? sagaFile : seriesFile;
          final json = jsonDecode(await targetFile.readAsString());
          if (json['name'] != null && !result.containsKey('saga')) {
            result['saga'] = json['name'].toString();
          }
          if (json['readingOrder'] != null &&
              !result.containsKey('readingOrder')) {
            result['readingOrder'] = json['readingOrder'];
          }
        } catch (_) {}
      }

      await readNamed('era.metadata.json', 'era');

      if (current.path == root.path) break;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  } catch (_) {}
  return result;
}

/// Writes author/universe/saga/era metadata files in parent hierarchy if missing.
Future<void> ensureParentMetadataFiles({
  required String dirPath,
  required String rootDirectoryPath,
  String? author,
  String? universe,
  String? saga,
  String? era,
}) async {
  try {
    var current = Directory(dirPath);
    final root = Directory(rootDirectoryPath);

    while (current.path != root.path && current.path.startsWith(root.path)) {
      final currentName = p.basename(current.path);

      String? order;
      final prefixMatch =
          RegExp(r'^\s*(\d+(?:\.\d+)?)\s*[-._\)\s]').firstMatch(currentName);
      if (prefixMatch != null) {
        order = prefixMatch.group(1);
      } else {
        final suffixMatch =
            RegExp(r'[-._\)\s](\d+(?:\.\d+)?)\s*$').firstMatch(currentName);
        if (suffixMatch != null) {
          order = suffixMatch.group(1);
        }
      }

      Future<void> writeIfMissing(
        String fileName,
        String name,
        String type,
      ) async {
        final file = File(p.join(current.path, fileName));
        if (await file.exists()) return;
        final data = <String, dynamic>{'name': name, 'type': type};
        if (order != null) data['readingOrder'] = order;
        const encoder = JsonEncoder.withIndent('  ');
        await file.writeAsString('${encoder.convert(data)}\n');
      }

      if (author != null &&
          currentName.toLowerCase() == author.toLowerCase()) {
        await writeIfMissing('author.metadata.json', author, 'author');
      }
      if (universe != null &&
          currentName.toLowerCase() == universe.toLowerCase()) {
        await writeIfMissing('universe.metadata.json', universe, 'universe');
      }
      if (saga != null &&
          (currentName.toLowerCase() == saga.toLowerCase() ||
              stripOrderPrefix(currentName).toLowerCase() ==
                  saga.toLowerCase())) {
        await writeIfMissing('saga.metadata.json', saga, 'saga');
        await writeIfMissing('series.metadata.json', saga, 'series');
      }
      if (era != null &&
          (currentName.toLowerCase() == era.toLowerCase() ||
              stripOrderPrefix(currentName).toLowerCase() ==
                  era.toLowerCase())) {
        await writeIfMissing('era.metadata.json', era, 'era');
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  } catch (_) {}
}
