import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';
import '../models/audiobook.dart';
import '../services/library_storage.dart';
import '../service_locator.dart';
import 'player_screen.dart';
import 'playlists_tab.dart';
import 'series_mapping_screen.dart';
import 'google_drive_screen.dart';
import 'ebook_reader_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(),
      child: const _HomeScreenView(),
    );
  }
}

class _HomeScreenView extends StatefulWidget {
  const _HomeScreenView();

  @override
  State<_HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<_HomeScreenView> {
  int _currentIndex = 0;
  bool _autoResumeTriggered = false;

  Future<void> _autoResumeLastBook(List<Audiobook> audiobooks) async {
    if (_autoResumeTriggered || audiobooks.isEmpty) return;
    _autoResumeTriggered = true;
    
    final lastPlayedPath = await getIt<LibraryStorage>().getLastPlayedBook();
    if (lastPlayedPath != null) {
      Audiobook? match;
      for (final b in audiobooks) {
        if (b.path == lastPlayedPath) {
          match = b;
          break;
        }
      }
      if (match != null && mounted) {
        // Delay slightly to ensure home screen is fully laid out
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _openPlayer(context, match!);
          }
        });
      }
    }
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    String? path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to scan for audiobooks',
    );

    if (path != null && path.isNotEmpty) {
      await cubit.scanDirectory(path);
    }
  }

  void _openPlayer(BuildContext context, Audiobook audiobook) {
    final cubit = context.read<HomeCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: cubit,
          child: PlayerScreen(audiobook: audiobook),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, state) {
        if (!state.isLoading && state.audiobooks.isNotEmpty) {
          _autoResumeLastBook(state.audiobooks);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            title: const Text(
              'AudioStitch',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: const Color(0xFF252525),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SeriesMappingScreen()),
                  );
                },
                tooltip: 'Settings',
              ),
              if (state.scanPaths.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: state.isLoading || state.isScanning ? null : () => context.read<HomeCubit>().rescanAll(),
                  tooltip: 'Rescan all folders',
                ),
            ],
          ),
          body: _currentIndex == 0 
              ? _buildLibraryTab(context, state) 
              : (_currentIndex == 1 ? _buildEbookLibraryTab(context, state) : const PlaylistsTab()),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: const Color(0xFF252525),
            selectedItemColor: const Color(0xFFE8B86D),
            unselectedItemColor: Colors.white54,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.headphones), label: 'Audiobooks'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Ebooks'),
              BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlists'),
            ],
          ),
          floatingActionButton: _currentIndex == 2
              ? FloatingActionButton(
                  backgroundColor: const Color(0xFFE8B86D),
                  onPressed: () => _showCreatePlaylistDialog(context),
                  child: const Icon(Icons.add, color: Color(0xFF1A1A1A)),
                )
              : FloatingActionButton(
                  backgroundColor: const Color(0xFFE8B86D),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GoogleDriveScreen()),
                    );
                  },
                  tooltip: 'Google Drive',
                  child: const Icon(Icons.cloud, color: Color(0xFF1A1A1A)),
                ),
        );
      },
    );
  }


  Widget _buildLibraryTab(BuildContext context, HomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddFolderSection(context, state),
        if (state.isScanning) _buildScanningProgress(context, state),
        if (state.fetchingMetadata.isNotEmpty) _buildMetadataProgress(context, state),
        if (state.error != null) _buildErrorBanner(state.error!),
        Expanded(
          child: state.audiobooks.isEmpty && !state.isLoading && !state.isScanning
              ? _buildEmptyState()
              : _buildAudiobookList(context, state),
        ),
      ],
    );
  }

  Widget _buildEbookLibraryTab(BuildContext context, HomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddFolderSection(context, state),
        if (state.isScanning) _buildScanningProgress(context, state),
        if (state.error != null) _buildErrorBanner(state.error!),
        Expanded(
          child: state.ebooks.isEmpty && !state.isLoading && !state.isScanning
              ? _buildEmptyStateEbooks()
              : _buildEbookList(context, state),
        ),
      ],
    );
  }

  Widget _buildAddFolderSection(BuildContext context, HomeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF252525),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.isLoading || state.isScanning ? null : () => _pickDirectory(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Add folder to scan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8B86D),
                side: const BorderSide(color: Color(0xFFE8B86D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (state.scanPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Scan folders (${state.scanPaths.length})',
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
              children: state.scanPaths.map((path) {
                final shortPath = path.length > 40 ? '${path.substring(0, 37)}...' : path;
                return Chip(
                  label: Text(shortPath, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                  onDeleted: state.isScanning ? null : () => context.read<HomeCubit>().removePath(path),
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

  Widget _buildErrorBanner(String error) {
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
              error,
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
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'No audiobooks yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add folder to scan" to select a directory\ncontaining audiobooks (.m4b)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningProgress(BuildContext context, HomeState state) {
    final pct = state.scanProgress ?? 0.0;
    return Container(
      color: const Color(0xFF252525),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanning... ${(pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                onPressed: () => context.read<HomeCubit>().cancelScan(),
                icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 20),
                label: const Text('Stop', style: TextStyle(color: Colors.redAccent)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataProgress(BuildContext context, HomeState state) {
    final total = state.metadataFetchTotalCount;
    final remaining = state.fetchingMetadata.length;
    final completed = total - remaining;
    final pct = total > 0 ? (completed / total) : 0.0;

    return Container(
      color: const Color(0xFF252525),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updating metadata... $completed/$total',
                style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                onPressed: () => context.read<HomeCubit>().cancelMetadataFetch(),
                icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 20),
                label: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String?, List<Audiobook>>> _groupAudiobooks(List<Audiobook> audiobooks) {
    final Map<String, Map<String?, List<Audiobook>>> grouped = {};
    for (var book in audiobooks) {
      grouped.putIfAbsent(book.author, () => {});
      grouped[book.author]!.putIfAbsent(book.series, () => []);
      grouped[book.author]![book.series]!.add(book);
    }
    return grouped;
  }

  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'\d+|\D+');
    final matchesA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (cmp != 0) return cmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  Widget _buildAudiobookList(BuildContext context, HomeState state) {
    if (state.audiobooks.isEmpty) return const SizedBox.shrink();

    final grouped = _groupAudiobooks(state.audiobooks);
    final authors = grouped.keys.toList()..sort(_naturalCompare);

    return Column(
      children: [
        if (state.isLoading && !state.isScanning)
          const LinearProgressIndicator(color: Color(0xFFE8B86D), backgroundColor: Colors.transparent),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE8B86D),
            backgroundColor: const Color(0xFF252525),
            onRefresh: () async {
              await context.read<HomeCubit>().rescanAll();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: authors.length,
              itemBuilder: (context, index) {
                final author = authors[index];
                final seriesMap = grouped[author]!;
                final seriesKeys = seriesMap.keys.toList()..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

              return ExpansionTile(
                initiallyExpanded: true,
                iconColor: const Color(0xFFE8B86D),
                collapsedIconColor: Colors.white70,
                title: Text(author, style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.bold, fontSize: 18)),
                children: seriesKeys.map((series) {
                  final books = seriesMap[series]!;
                  books.sort((a, b) {
                    // 1. Try sorting by seriesSequence (saga number)
                    if (a.seriesSequence != null && b.seriesSequence != null) {
                      final numA = double.tryParse(a.seriesSequence!);
                      final numB = double.tryParse(b.seriesSequence!);
                      if (numA != null && numB != null) {
                        final cmp = numA.compareTo(numB);
                        if (cmp != 0) return cmp;
                      } else {
                        final cmp = _naturalCompare(a.seriesSequence!, b.seriesSequence!);
                        if (cmp != 0) return cmp;
                      }
                    } else if (a.seriesSequence != null) {
                      return -1;
                    } else if (b.seriesSequence != null) {
                      return 1;
                    }

                    // 2. Try sorting by publishYear
                    if (a.publishYear != null && b.publishYear != null) {
                      final numA = int.tryParse(a.publishYear!);
                      final numB = int.tryParse(b.publishYear!);
                      if (numA != null && numB != null) {
                        final cmp = numA.compareTo(numB);
                        if (cmp != 0) return cmp;
                      } else {
                        final cmp = a.publishYear!.compareTo(b.publishYear!);
                        if (cmp != 0) return cmp;
                      }
                    } else if (a.publishYear != null) {
                      return -1;
                    } else if (b.publishYear != null) {
                      return 1;
                    }

                    // 3. Fallback to natural alphabetical sort on title
                    return _naturalCompare(a.title, b.title);
                  });

                  if (series != null) {
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.only(left: 32, right: 16),
                        iconColor: Colors.white70,
                        collapsedIconColor: Colors.white54,
                        title: Text(series, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15)),
                        children: books.map((book) {
                          final prefix = book.seriesSequence != null
                              ? 'Book ${book.seriesSequence} - '
                              : (book.publishYear != null ? '${book.publishYear} - ' : '');
                          return _buildAudiobookTile(context, state, book, prefix: prefix);
                        }).toList(),
                      ),
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: books.map((book) => _buildAudiobookTile(context, state, book)).toList(),
                    );
                  }
                }).toList(),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudiobookTile(BuildContext context, HomeState state, Audiobook book, {String prefix = ''}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE8B86D).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            book.coverPath != null
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.audiotrack, color: Color(0xFFE8B86D), size: 28))
                : const Icon(Icons.audiotrack, color: Color(0xFFE8B86D), size: 28),
            if (book.isRead)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Icon(Icons.check_circle, color: Color(0xFFE8B86D), size: 24),
              ),
          ],
        ),
      ),
      title: Text(
        '$prefix${book.title}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${book.author}${book.narrator != null ? ' (read by ${book.narrator})' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${book.durationFormatted} • ${book.totalChapters} chapters${book.publishYear != null ? ' • ${book.publishYear}' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (book.description != null && book.description!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              book.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ]
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.fetchingMetadata.containsKey(book.path))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8B86D)),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF333333),
            onSelected: (value) {
              if (value == 'refresh') {
                context.read<HomeCubit>().forceFetchMetadata(book);
              } else if (value == 'toggle_read') {
                context.read<HomeCubit>().toggleReadStatus(book);
              } else if (value == 'add_playlist') {
                _showAddToPlaylistDialog(context, state, book);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggle_read',
                child: Row(
                  children: [
                    Icon(book.isRead ? Icons.remove_done : Icons.done_all, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Text(book.isRead ? 'Mark as Unread' : 'Mark as Read', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'add_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh Metadata', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.play_circle_fill, color: Color(0xFFE8B86D), size: 36),
        ],
      ),
      onTap: () => _openPlayer(context, book),
    );
  }

  Widget _buildEmptyStateEbooks() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'No ebooks yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add folder to scan" to select a directory\ncontaining ebooks (.epub, .pdf)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEbookList(BuildContext context, HomeState state) {
    if (state.ebooks.isEmpty) return const SizedBox.shrink();

    // Grouping by author and series, similar to audiobooks
    final Map<String, Map<String?, List<dynamic>>> grouped = {};
    for (var book in state.ebooks) {
      grouped.putIfAbsent(book.author, () => {});
      grouped[book.author]!.putIfAbsent(book.series, () => []);
      grouped[book.author]![book.series]!.add(book);
    }
    final authors = grouped.keys.toList()..sort(_naturalCompare);

    return Column(
      children: [
        if (state.isLoading && !state.isScanning)
          const LinearProgressIndicator(color: Color(0xFFE8B86D), backgroundColor: Colors.transparent),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE8B86D),
            backgroundColor: const Color(0xFF252525),
            onRefresh: () async {
              await context.read<HomeCubit>().rescanAll();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: authors.length,
              itemBuilder: (context, index) {
                final author = authors[index];
                final seriesMap = grouped[author]!;
                final seriesKeys = seriesMap.keys.toList()..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

              return ExpansionTile(
                initiallyExpanded: true,
                iconColor: const Color(0xFFE8B86D),
                collapsedIconColor: Colors.white70,
                title: Text(author, style: const TextStyle(color: Color(0xFFE8B86D), fontWeight: FontWeight.bold, fontSize: 18)),
                children: seriesKeys.map((series) {
                  final books = seriesMap[series]!;
                  books.sort((a, b) {
                    if (a.seriesSequence != null && b.seriesSequence != null) {
                      final numA = double.tryParse(a.seriesSequence!);
                      final numB = double.tryParse(b.seriesSequence!);
                      if (numA != null && numB != null) {
                        return numA.compareTo(numB);
                      }
                      return _naturalCompare(a.seriesSequence!, b.seriesSequence!);
                    } else if (a.seriesSequence != null) {
                      return -1;
                    } else if (b.seriesSequence != null) {
                      return 1;
                    }

                    if (a.publishYear != null && b.publishYear != null) {
                      final numA = int.tryParse(a.publishYear!);
                      final numB = int.tryParse(b.publishYear!);
                      if (numA != null && numB != null) return numA.compareTo(numB);
                      return a.publishYear!.compareTo(b.publishYear!);
                    } else if (a.publishYear != null) {
                      return -1;
                    } else if (b.publishYear != null) {
                      return 1;
                    }

                    return _naturalCompare(a.title, b.title);
                  });

                  if (series != null) {
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.only(left: 32, right: 16),
                        iconColor: Colors.white70,
                        collapsedIconColor: Colors.white54,
                        title: Text(series, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15)),
                        children: books.map((book) {
                          final prefix = book.seriesSequence != null
                              ? 'Book ${book.seriesSequence} - '
                              : (book.publishYear != null ? '${book.publishYear} - ' : '');
                          return _buildEbookTile(context, state, book, prefix: prefix);
                        }).toList(),
                      ),
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: books.map((book) => _buildEbookTile(context, state, book)).toList(),
                    );
                  }
                }).toList(),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildEbookTile(BuildContext context, HomeState state, dynamic book, {String prefix = ''}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE8B86D).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            book.coverPath != null
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.book, color: Color(0xFFE8B86D), size: 28))
                : const Icon(Icons.book, color: Color(0xFFE8B86D), size: 28),
            if (book.isRead)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Icon(Icons.check_circle, color: Color(0xFFE8B86D), size: 24),
              ),
          ],
        ),
      ),
      title: Text(
        '$prefix${book.title}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.author,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${book.isPdf ? 'PDF' : 'EPUB'}${book.publishYear != null ? ' • ${book.publishYear}' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (book.description != null && book.description!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              book.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ]
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.fetchingMetadata.containsKey(book.file))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8B86D)),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF333333),
            onSelected: (value) {
              if (value == 'refresh') {
                context.read<HomeCubit>().forceFetchEbookMetadata(book);
              } else if (value == 'toggle_read') {
                // To be implemented: toggle read status for ebook
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggle_read',
                child: Row(
                  children: [
                    Icon(book.isRead ? Icons.remove_done : Icons.done_all, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Text(book.isRead ? 'Mark as Unread' : 'Mark as Read', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh Metadata', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.auto_stories, color: Color(0xFFE8B86D), size: 36),
        ],
      ),
      onTap: () {
        EbookReader.open(context, book);
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, HomeState state, Audiobook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.playlists.length,
            itemBuilder: (ctx, i) {
              final p = state.playlists[i];
              return ListTile(
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  context.read<HomeCubit>().addBookToPlaylist(p.id!, book.path);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${p.name}'), backgroundColor: const Color(0xFF252525)));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<HomeCubit>().createPlaylist(controller.text);
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFFE8B86D))),
          ),
        ],
      ),
    );
  }
}
