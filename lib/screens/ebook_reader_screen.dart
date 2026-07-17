import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_epub_reader/flutter_epub_reader.dart';

import '../models/ebook.dart';

class EbookReader {
  static void open(BuildContext context, Ebook ebook) {
    if (ebook.isEpub) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpubReaderScreen(ebook: ebook),
        ),
      );
    } else if (ebook.isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfReaderScreen(ebook: ebook),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported ebook format')),
      );
    }
  }
}

class PdfReaderScreen extends StatelessWidget {
  final Ebook ebook;

  const PdfReaderScreen({super.key, required this.ebook});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ebook.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(
        File(ebook.file),
      ),
    );
  }
}

class EpubReaderScreen extends StatefulWidget {
  final Ebook ebook;

  const EpubReaderScreen({super.key, required this.ebook});

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  final epubController = EpubController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ebook.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: EpubViewer(
          epubSource: EpubSource.fromFile(File(widget.ebook.file)),
          epubController: epubController,
          displaySettings: EpubDisplaySettings(flow: EpubFlow.paginated, snap: true),
        ),
      ),
    );
  }
}
