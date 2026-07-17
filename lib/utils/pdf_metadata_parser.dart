import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfMetadataParser {
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
      final document = PdfDocument(inputBytes: bytes);
      
      final info = document.documentInformation;
      
      if (info.title.isNotEmpty) {
        result['title'] = info.title;
      }
      if (info.author.isNotEmpty) {
        result['author'] = info.author;
      }
      if (info.subject.isNotEmpty) {
        result['description'] = info.subject;
      }
      result['publishYear'] = info.creationDate.year.toString();

      document.dispose();
    } catch (e) {
      // Error parsing PDF metadata
    }

    return result;
  }
}
