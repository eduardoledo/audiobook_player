import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class EpubMetadataParser {
  static Future<Map<String, String?>> parse(File file) async {
    final result = <String, String?>{
      'title': null,
      'author': null,
      'description': null,
      'publishYear': null,
      'series': null,
      'coverPath': null,
    };

    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find container.xml
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) return result;

      final containerXml = XmlDocument.parse(String.fromCharCodes(containerFile.content as List<int>));
      final rootfile = containerXml.findAllElements('rootfile').firstOrNull;
      if (rootfile == null) return result;

      final opfPath = rootfile.getAttribute('full-path');
      if (opfPath == null) return result;

      final opfFile = archive.findFile(opfPath);
      if (opfFile == null) return result;

      final opfXml = XmlDocument.parse(String.fromCharCodes(opfFile.content as List<int>));
      
      // Parse metadata
      final metadata = opfXml.findAllElements('metadata').firstOrNull;
      if (metadata != null) {
        result['title'] = metadata.findAllElements('dc:title').firstOrNull?.innerText;
        result['author'] = metadata.findAllElements('dc:creator').firstOrNull?.innerText;
        result['description'] = metadata.findAllElements('dc:description').firstOrNull?.innerText;
        result['publishYear'] = metadata.findAllElements('dc:date').firstOrNull?.innerText;

        // Try to find series (calibre specific or general meta)
        final metas = metadata.findAllElements('meta');
        for (final meta in metas) {
          if (meta.getAttribute('name') == 'calibre:series') {
            result['series'] = meta.getAttribute('content');
          }
        }
      }

      // Find cover image
      final manifest = opfXml.findAllElements('manifest').firstOrNull;
      if (manifest != null) {
        String? coverItemId;
        
        // Sometimes cover is specified in meta
        final metas = opfXml.findAllElements('meta');
        for (final meta in metas) {
          if (meta.getAttribute('name') == 'cover') {
            coverItemId = meta.getAttribute('content');
          }
        }

        ArchiveFile? coverImageFile;
        final items = manifest.findAllElements('item');
        
        for (final item in items) {
          final id = item.getAttribute('id');
          final properties = item.getAttribute('properties');
          
          if (id == coverItemId || (properties != null && properties.contains('cover-image'))) {
            final href = item.getAttribute('href');
            if (href != null) {
              final opfDir = p.dirname(opfPath);
              final coverPathInArchive = opfDir == '.' ? href : p.normalize(p.join(opfDir, href));
              coverImageFile = archive.findFile(coverPathInArchive);
              break;
            }
          }
        }

        if (coverImageFile != null) {
          final coverData = coverImageFile.content as List<int>;
          final baseDir = file.parent.path;
          final originalFileName = p.basenameWithoutExtension(file.path);
          final coverPath = p.join(baseDir, '.$originalFileName' '_cover.jpg');
          
          await File(coverPath).writeAsBytes(coverData);
          result['coverPath'] = coverPath;
        }
      }
    } catch (e) {
      print('Error parsing EPUB metadata: $e');
    }

    return result;
  }
}
