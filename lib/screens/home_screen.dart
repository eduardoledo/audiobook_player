import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import '../services/audiobook_scanner.dart';
import '../services/library_storage.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _scanPaths = [];
  List<Audiobook> _audiobooks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _scanPaths = [];
      _audiobooks = [];
      _error = null;
    });
    final paths = await LibraryStorage.getScanPaths();
    final books = await LibraryStorage.getAudiobooks();
    setState(() {
      _scanPaths = paths;
      _audiobooks = books;
    });
  }

  Future<void> _pickDirectory() async {
    String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to scan for audiobooks',
    );

    if (path != null && path.isNotEmpty) {
      await _scanDirectory(path);
    }
  }

  Future<void> _scanDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final books = await AudiobookScanner.scanDirectory(path);
      await LibraryStorage.addScanPath(path);
      await LibraryStorage.saveAudiobooks([..._audiobooks, ...books]);

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rescanAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allBooks = <Audiobook>[];
      for (final path in _scanPaths) {
        if (await Directory(path).exists()) {
          final books = await AudiobookScanner.scanDirectory(path);
          allBooks.addAll(books);
        }
      }
      await LibraryStorage.saveAudiobooks(allBooks);

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removePath(String path) async {
    await LibraryStorage.removeScanPath(path);
    final remainingPaths = _scanPaths.where((p) => p != path).toList();
    final books = _audiobooks.where((b) {
      return remainingPaths.any((p) =>
          b.path == p || b.path.startsWith('$p${Platform.pathSeparator}'));
    }).toList();
    await LibraryStorage.saveAudiobooks(books);
    await _load();
  }

  void _openPlayer(Audiobook audiobook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(audiobook: audiobook),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Audiobook Player',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_scanPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _rescanAll,
              tooltip: 'Rescan all folders',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddFolderSection(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE8B86D)),
                  )
                : _audiobooks.isEmpty
                    ? _buildEmptyState()
                    : _buildAudiobookList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFolderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF252525),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('Add folder to scan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8B86D),
                side: const BorderSide(color: Color(0xFFE8B86D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_scanPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Scan folders (${_scanPaths.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scanPaths.map((path) {
                final shortPath = path.length > 40 ? '${path.substring(0, 37)}...' : path;
                return Chip(
                  label: Text(shortPath, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                  onDeleted: () => _removePath(path),
                  backgroundColor: const Color(0xFF333333),
                  labelStyle: const TextStyle(color: Colors.white70),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.headphones,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'No audiobooks yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add folder to scan" to select a directory\ncontaining audiobooks (.m4b)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudiobookList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _audiobooks.length,
      itemBuilder: (context, index) {
        final book = _audiobooks[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8B86D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.audiotrack, color: Color(0xFFE8B86D), size: 28),
          ),
          title: Text(
            book.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '${book.author} • ${book.durationFormatted} • ${book.totalChapters} chapters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFE8B86D), size: 36),
          onTap: () => _openPlayer(book),
        );
      },
    );
  }
}
