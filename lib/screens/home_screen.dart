import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';
import '../dialogs/path_structure_selector_dialog.dart';
import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../services/audiobook_scanner.dart';
import '../services/library_storage.dart';
import '../service_locator.dart';
import 'player_screen.dart';
import 'playlists_tab.dart';
import 'series_mapping_screen.dart';
import 'google_drive_screen.dart';
import 'ebook_reader_screen.dart';
import '../utils/structure_detection_flow.dart';
import '../widgets/structure_detection_banner.dart';

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
  bool _isFolderView = false;
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
          drawer: Drawer(
            backgroundColor: const Color(0xFF252525),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF1A1A1A)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_special, size: 48, color: Color(0xFFE8B86D)),
                      SizedBox(height: 8),
                      Text(
                        'Estructuras y Biblioteca',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (state.scanPaths.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Carpetas de Biblioteca (${state.scanPaths.length})',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFFE8B86D), size: 18),
                        tooltip: 'Re-escanear biblioteca',
                        onPressed: state.isScanning ? null : () => context.read<HomeCubit>().rescanAll(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...state.scanPaths.map((rootPath) {
                    final Set<String> allDirectories = {};
                    
                    void collectDirectories(String dirPath) {
                      allDirectories.add(dirPath);
                      final parent = p.dirname(dirPath);
                      if (parent != dirPath && parent.startsWith(rootPath) && parent.length >= rootPath.length) {
                        collectDirectories(parent);
                      }
                    }

                    for (final b in state.audiobooks) {
                      if (b.path.startsWith(rootPath)) {
                        collectDirectories(b.path);
                      }
                    }
                    for (final eb in state.ebooks) {
                      final dir = p.dirname(eb.path);
                      if (dir.startsWith(rootPath)) {
                        collectDirectories(dir);
                      }
                    }

                    final subDirs = allDirectories
                        .where((d) => d != rootPath)
                        .toList()
                      ..sort();

                    return ExpansionTile(
                      key: PageStorageKey<String>(rootPath),
                      initiallyExpanded: true,
                      tilePadding: EdgeInsets.zero,
                      iconColor: const Color(0xFFE8B86D),
                      collapsedIconColor: Colors.white60,
                      leading: const Icon(Icons.folder_special, color: Color(0xFFE8B86D)),
                      title: Text(
                        rootPath,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Directorio Raíz (${subDirs.length} subcarpetas)',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.account_tree, color: Color(0xFFE8B86D), size: 20),
                            tooltip: 'Configurar estructura de la carpeta raíz',
                            onPressed: () async {
                              final homeCubit = context.read<HomeCubit>();
                              final updated = await showDialog<bool>(
                                context: context,
                                builder: (_) => PathStructureSelectorDialog(rootPath: rootPath),
                              );
                              if (updated == true && context.mounted) {
                                homeCubit.rescanAll();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                            onPressed: state.isScanning
                                ? null
                                : () => context.read<HomeCubit>().removePath(rootPath),
                          ),
                        ],
                      ),
                      children: subDirs.map((subPath) {
                        final relativeDepth = p.split(p.relative(subPath, from: rootPath)).length;
                        final indent = (relativeDepth - 1) * 12.0;

                        return Padding(
                          padding: EdgeInsets.only(left: 12.0 + indent, bottom: 4.0),
                          child: Card(
                            color: const Color(0xFF2A2A2A),
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder, color: Color(0xFFE8B86D), size: 18),
                              title: Text(
                                subPath,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.account_tree, color: Color(0xFFE8B86D), size: 18),
                                tooltip: 'Configurar roles de esta subcarpeta',
                                onPressed: () async {
                                  final homeCubit = context.read<HomeCubit>();
                                  final updated = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => PathStructureSelectorDialog(rootPath: subPath),
                                  );
                                  if (updated == true && context.mounted) {
                                    homeCubit.rescanAll();
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No hay carpetas de biblioteca agregadas aún.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          appBar: AppBar(
            title: const Text(
              'AudioStitch',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            backgroundColor: const Color(0xFF252525),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  _isFolderView ? Icons.view_module : Icons.folder_copy,
                ),
                onPressed: () => setState(() => _isFolderView = !_isFolderView),
                tooltip: _isFolderView ? 'Vista por categorías' : 'Vista por carpetas',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SeriesMappingScreen(),
                    ),
                  );
                },
                tooltip: 'Settings',
              ),
              if (state.scanPaths.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: state.isLoading || state.isScanning
                      ? null
                      : () => context.read<HomeCubit>().rescanAll(),
                  tooltip: 'Rescan all folders',
                ),
            ],
          ),
          body: Column(
            children: [
              const StructureDetectionBanner(),
              Expanded(
                child: _currentIndex == 0
                    ? _buildLibraryTab(context, state)
                    : (_currentIndex == 1
                          ? _buildEbookLibraryTab(context, state)
                          : const PlaylistsTab()),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: const Color(0xFF252525),
            selectedItemColor: const Color(0xFFE8B86D),
            unselectedItemColor: Colors.white54,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.headphones),
                label: 'Audiobooks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book),
                label: 'Ebooks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.playlist_play),
                label: 'Playlists',
              ),
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
                      MaterialPageRoute(
                        builder: (context) => const GoogleDriveScreen(),
                      ),
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
        if (state.fetchingMetadata.isNotEmpty)
          _buildMetadataProgress(context, state),
        if (state.error != null) _buildErrorBanner(state.error!),
        Expanded(
          child:
              state.audiobooks.isEmpty && !state.isLoading && !state.isScanning
              ? _buildEmptyState()
              : (_isFolderView
                    ? _buildDirectoryView(context, state, state.audiobooks)
                    : _buildAudiobookList(context, state)),
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
              : (_isFolderView
                    ? _buildDirectoryView(context, state, state.ebooks)
                    : _buildEbookList(context, state)),
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
              onPressed: state.isLoading || state.isScanning
                  ? null
                  : () => _pickDirectory(context),
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
                final shortPath = path.length > 35
                    ? '${path.substring(0, 32)}...'
                    : path;
                return Chip(
                  avatar: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.account_tree, size: 16, color: Color(0xFFE8B86D)),
                    tooltip: 'Configurar estructura de carpeta',
                    onPressed: () async {
                      final homeCubit = context.read<HomeCubit>();
                      final updated = await showDialog<bool>(
                        context: context,
                        builder: (_) => PathStructureSelectorDialog(
                          rootPath: path,
                        ),
                      );
                      if (updated == true && mounted) {
                        homeCubit.rescanAll();
                      }
                    },
                  ),
                  label: Text(shortPath, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white70,
                  ),
                  onDeleted: state.isScanning
                      ? null
                      : () => context.read<HomeCubit>().removePath(path),
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
                style: const TextStyle(
                  color: Color(0xFFE8B86D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.read<HomeCubit>().cancelScan(),
                icon: const Icon(
                  Icons.stop_circle,
                  color: Colors.redAccent,
                  size: 20,
                ),
                label: const Text(
                  'Stop',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                style: const TextStyle(
                  color: Color(0xFFE8B86D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.read<HomeCubit>().cancelMetadataFetch(),
                icon: const Icon(
                  Icons.stop_circle,
                  color: Colors.redAccent,
                  size: 20,
                ),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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

  Map<String, Map<String?, Map<String?, List<Audiobook>>>> _groupAudiobooks(
    List<Audiobook> audiobooks,
  ) {
    final Map<String, Map<String?, Map<String?, List<Audiobook>>>> grouped = {};
    for (var book in audiobooks) {
      grouped.putIfAbsent(book.author, () => {});
      grouped[book.author]!.putIfAbsent(book.universe, () => {});
      grouped[book.author]![book.universe]!.putIfAbsent(book.series, () => []);
      grouped[book.author]![book.universe]![book.series]!.add(book);
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
          const LinearProgressIndicator(
            color: Color(0xFFE8B86D),
            backgroundColor: Colors.transparent,
          ),
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
                final universeMap = grouped[author]!;
                final universeKeys = universeMap.keys.toList()
                  ..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

                return ExpansionTile(
                  initiallyExpanded: true,
                  iconColor: const Color(0xFFE8B86D),
                  collapsedIconColor: Colors.white70,
                  title: Text(
                    author,
                    style: const TextStyle(
                      color: Color(0xFFE8B86D),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  children: universeKeys.map((universe) {
                    final seriesMap = universeMap[universe]!;
                    final seriesKeys = seriesMap.keys.toList()
                      ..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

                    final seriesChildren = seriesKeys.map((series) {
                      final books = seriesMap[series]!;
                      books.sort((a, b) {
                        if (a.seriesSequence != null &&
                            b.seriesSequence != null) {
                          final numA = double.tryParse(a.seriesSequence!);
                          final numB = double.tryParse(b.seriesSequence!);
                          if (numA != null && numB != null) {
                            final cmp = numA.compareTo(numB);
                            if (cmp != 0) return cmp;
                          } else {
                            final cmp = _naturalCompare(
                              a.seriesSequence!,
                              b.seriesSequence!,
                            );
                            if (cmp != 0) return cmp;
                          }
                        } else if (a.seriesSequence != null) {
                          return -1;
                        } else if (b.seriesSequence != null) {
                          return 1;
                        }

                        if (a.publishYear != null && b.publishYear != null) {
                          final numA = int.tryParse(a.publishYear!);
                          final numB = int.tryParse(b.publishYear!);
                          if (numA != null && numB != null) {
                            final cmp = numA.compareTo(numB);
                            if (cmp != 0) return cmp;
                          } else {
                            final cmp = a.publishYear!.compareTo(
                              b.publishYear!,
                            );
                            if (cmp != 0) return cmp;
                          }
                        } else if (a.publishYear != null) {
                          return -1;
                        } else if (b.publishYear != null) {
                          return 1;
                        }

                        return _naturalCompare(a.title, b.title);
                      });

                      if (series != null) {
                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.only(
                              left: 32,
                              right: 16,
                            ),
                            iconColor: Colors.white70,
                            collapsedIconColor: Colors.white54,
                            title: Text(
                              series,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            children: books.map((book) {
                              final prefix = book.seriesSequence != null
                                  ? 'Book ${book.seriesSequence} - '
                                  : (book.publishYear != null
                                        ? '${book.publishYear} - '
                                        : '');
                              return _buildAudiobookTile(
                                context,
                                state,
                                book,
                                prefix: prefix,
                              );
                            }).toList(),
                          ),
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: books
                              .map(
                                (book) =>
                                    _buildAudiobookTile(context, state, book),
                              )
                              .toList(),
                        );
                      }
                    }).toList();

                    if (universe != null) {
                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: const EdgeInsets.only(
                            left: 24,
                            right: 16,
                          ),
                          iconColor: const Color(
                            0xFFE8B86D,
                          ).withValues(alpha: 0.8),
                          collapsedIconColor: Colors.white60,
                          title: Text(
                            'Universo: $universe',
                            style: const TextStyle(
                              color: Color(0xFFE8B86D),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          children: seriesChildren,
                        ),
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: seriesChildren,
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

  Widget _buildAudiobookTile(
    BuildContext context,
    HomeState state,
    Audiobook book, {
    String prefix = '',
  }) {
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
                ? Image.file(
                    File(book.coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.audiotrack,
                      color: Color(0xFFE8B86D),
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.audiotrack,
                    color: Color(0xFFE8B86D),
                    size: 28,
                  ),
            if (book.isRead)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE8B86D),
                  size: 24,
                ),
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
          ],
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE8B86D),
                ),
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
              } else if (value == 'view_paths') {
                _showFilePathsDialog(context, book);
              } else if (value == 'detect_structure') {
                runStructureDetectionFlow(context, book);
              } else if (value == 'path_roles') {
                showDialog<bool>(
                  context: context,
                  builder: (_) => PathStructureSelectorDialog(rootPath: book.path),
                ).then((updated) {
                  if (updated == true && context.mounted) {
                    context.read<HomeCubit>().rescanAll();
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'path_roles',
                child: const Row(
                  children: [
                    Icon(Icons.account_tree, color: Color(0xFFE8B86D)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Estructura de la ruta',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'toggle_read',
                child: Row(
                  children: [
                    Icon(
                      book.isRead ? Icons.remove_done : Icons.done_all,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      book.isRead ? 'Mark as Unread' : 'Mark as Read',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'add_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Add to Playlist',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'detect_structure',
                child: Row(
                  children: [
                    Icon(Icons.account_tree, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Detectar estructura',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'view_paths',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'View File Paths',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Refresh Metadata',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.play_circle_fill,
            color: Color(0xFFE8B86D),
            size: 36,
          ),
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

    final Map<String, Map<String?, Map<String?, List<dynamic>>>> grouped = {};
    for (var book in state.ebooks) {
      grouped.putIfAbsent(book.author, () => {});
      grouped[book.author]!.putIfAbsent(book.universe, () => {});
      grouped[book.author]![book.universe]!.putIfAbsent(book.series, () => []);
      grouped[book.author]![book.universe]![book.series]!.add(book);
    }
    final authors = grouped.keys.toList()..sort(_naturalCompare);

    return Column(
      children: [
        if (state.isLoading && !state.isScanning)
          const LinearProgressIndicator(
            color: Color(0xFFE8B86D),
            backgroundColor: Colors.transparent,
          ),
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
                final universeMap = grouped[author]!;
                final universeKeys = universeMap.keys.toList()
                  ..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

                return ExpansionTile(
                  initiallyExpanded: true,
                  iconColor: const Color(0xFFE8B86D),
                  collapsedIconColor: Colors.white70,
                  title: Text(
                    author,
                    style: const TextStyle(
                      color: Color(0xFFE8B86D),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  children: universeKeys.map((universe) {
                    final seriesMap = universeMap[universe]!;
                    final seriesKeys = seriesMap.keys.toList()
                      ..sort((a, b) => _naturalCompare(a ?? '', b ?? ''));

                    final seriesChildren = seriesKeys.map((series) {
                      final books = seriesMap[series]!;
                      books.sort((a, b) {
                        if (a.seriesSequence != null &&
                            b.seriesSequence != null) {
                          final numA = double.tryParse(a.seriesSequence!);
                          final numB = double.tryParse(b.seriesSequence!);
                          if (numA != null && numB != null) {
                            return numA.compareTo(numB);
                          }
                          return _naturalCompare(
                            a.seriesSequence!,
                            b.seriesSequence!,
                          );
                        } else if (a.seriesSequence != null) {
                          return -1;
                        } else if (b.seriesSequence != null) {
                          return 1;
                        }

                        if (a.publishYear != null && b.publishYear != null) {
                          final numA = int.tryParse(a.publishYear!);
                          final numB = int.tryParse(b.publishYear!);
                          if (numA != null && numB != null) {
                            return numA.compareTo(numB);
                          }
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
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.only(
                              left: 32,
                              right: 16,
                            ),
                            iconColor: Colors.white70,
                            collapsedIconColor: Colors.white54,
                            title: Text(
                              series,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            children: books.map((book) {
                              final prefix = book.seriesSequence != null
                                  ? 'Book ${book.seriesSequence} - '
                                  : (book.publishYear != null
                                        ? '${book.publishYear} - '
                                        : '');
                              return _buildEbookTile(
                                context,
                                state,
                                book,
                                prefix: prefix,
                              );
                            }).toList(),
                          ),
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: books
                              .map(
                                (book) =>
                                    _buildEbookTile(context, state, book),
                              )
                              .toList(),
                        );
                      }
                    }).toList();

                    if (universe != null) {
                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: const EdgeInsets.only(
                            left: 24,
                            right: 16,
                          ),
                          iconColor: const Color(
                            0xFFE8B86D,
                          ).withValues(alpha: 0.8),
                          collapsedIconColor: Colors.white60,
                          title: Text(
                            'Universo: $universe',
                            style: const TextStyle(
                              color: Color(0xFFE8B86D),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          children: seriesChildren,
                        ),
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: seriesChildren,
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

  Widget _buildEbookTile(
    BuildContext context,
    HomeState state,
    dynamic book, {
    String prefix = '',
  }) {
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
                ? Image.file(
                    File(book.coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.book,
                      color: Color(0xFFE8B86D),
                      size: 28,
                    ),
                  )
                : const Icon(Icons.book, color: Color(0xFFE8B86D), size: 28),
            if (book.isRead)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE8B86D),
                  size: 24,
                ),
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
          ],
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE8B86D),
                ),
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
              } else if (value == 'view_paths') {
                _showFilePathsDialog(context, book);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggle_read',
                child: Row(
                  children: [
                    Icon(
                      book.isRead ? Icons.remove_done : Icons.done_all,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      book.isRead ? 'Mark as Unread' : 'Mark as Read',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'view_paths',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'View File Paths',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Refresh Metadata',
                      style: TextStyle(color: Colors.white),
                    ),
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

  void _showFilePathsDialog(BuildContext context, dynamic book) {
    final scanPaths = context.read<HomeCubit>().state.scanPaths;

    showDialog(
      context: context,
      builder: (context) {
        List<String> files = [];
        String bookPath = '';
        if (book.runtimeType.toString() == 'Audiobook') {
          files = (book as dynamic).files;
          bookPath = (book as dynamic).path;
        } else if (book.runtimeType.toString() == 'Ebook') {
          files = [(book as dynamic).file];
          bookPath = (book as dynamic).path;
        }

        String patternInfo = 'Desconocido';
        String? matchedBase;
        for (var sp in scanPaths) {
          if (bookPath.startsWith(sp)) {
            matchedBase = sp;
            break;
          }
        }

        if (matchedBase != null) {
          final rel = p.relative(bookPath, from: matchedBase);
          final segments = p
              .split(rel)
              .where((s) => s.isNotEmpty && s != '.')
              .toList();
          if (segments.length == 1) {
            patternInfo = 'Directorio Raíz / Título';
          } else if (segments.length == 2) {
            patternInfo = 'Autor / Título';
          } else if (segments.length == 3) {
            patternInfo = 'Autor / Saga / Título';
          } else if (segments.length == 4) {
            patternInfo = 'Autor / Universo / Saga / Título';
          } else if (segments.length >= 5) {
            patternInfo = 'Autor / Universo / Saga / Título / Parte(s)';
          } else {
            patternInfo = 'Raíz';
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: Text(
            'Archivos de ${book.title}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Patrón detectado: $patternInfo',
                    style: const TextStyle(
                      color: Color(0xFFE8B86D),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: SelectableText(
                          files[index],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Color(0xFFE8B86D)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    HomeState state,
    Audiobook book,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Add to Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.playlists.length,
            itemBuilder: (ctx, i) {
              final p = state.playlists[i];
              return ListTile(
                title: Text(
                  p.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  context.read<HomeCubit>().addBookToPlaylist(p.id!, book.path);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to ${p.name}'),
                      backgroundColor: const Color(0xFF252525),
                    ),
                  );
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
        title: const Text(
          'New Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE8B86D)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<HomeCubit>().createPlaylist(controller.text);
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: Color(0xFFE8B86D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryView(
    BuildContext context,
    HomeState state,
    List<dynamic> books,
  ) {
    if (books.isEmpty) return const SizedBox.shrink();

    final root = _buildDirectoryTree(books, state.scanPaths);

    return Column(
      children: [
        if (state.isLoading && !state.isScanning)
          const LinearProgressIndicator(
            color: Color(0xFFE8B86D),
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE8B86D),
            backgroundColor: const Color(0xFF252525),
            onRefresh: () async {
              await context.read<HomeCubit>().rescanAll();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildDirectoryNodeWidget(context, state, root, 0),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a folder tree using book paths as the template:
  /// `Autor / [Universo] / [Saga] / Libro` (via [AudiobookScanner.parseDirPath]).
  /// The audiobook/ebook is always the leaf.
  _DirectoryNode _buildDirectoryTree(
    List<dynamic> books,
    List<String> scanPaths,
  ) {
    final root = _DirectoryNode('Root');
    final bases = List<String>.from(scanPaths)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final book in books) {
      // Directory path is the template source (not the media file).
      final bookPath = book is Ebook
          ? book.path
          : (book as Audiobook).path;

      final matchedBase = _matchScanPath(bookPath, bases);
      final meta = matchedBase != null
          ? AudiobookScanner.parseDirPath(bookPath, matchedBase)
          : null;

      if (meta != null) {
        _DirectoryNode current = root;
        current = current.subdirectories.putIfAbsent(
          meta.author,
          () => _DirectoryNode(meta.author),
        );
        final universe = meta.universe?.trim();
        if (universe != null && universe.isNotEmpty) {
          current = current.subdirectories.putIfAbsent(
            universe,
            () => _DirectoryNode(universe),
          );
        }
        final saga = meta.saga?.trim();
        if (saga != null && saga.isNotEmpty) {
          current = current.subdirectories.putIfAbsent(
            saga,
            () => _DirectoryNode(saga),
          );
        }
        current.books.add(book);
        continue;
      }

      // Fallback: raw relative segments; last segment is the book leaf.
      if (matchedBase != null) {
        final rel = p.relative(bookPath, from: matchedBase);
        final segments = p
            .split(rel)
            .where((s) => s.isNotEmpty && s != '.')
            .toList();
        if (segments.isEmpty) {
          root.books.add(book);
          continue;
        }
        _DirectoryNode current = root;
        for (var i = 0; i < segments.length - 1; i++) {
          final seg = segments[i];
          current = current.subdirectories.putIfAbsent(
            seg,
            () => _DirectoryNode(seg),
          );
        }
        current.books.add(book);
      } else {
        root.books.add(book);
      }
    }

    _sortDirectoryTree(root);
    return root;
  }

  String? _matchScanPath(String bookPath, List<String> scanPathsLongestFirst) {
    for (final sp in scanPathsLongestFirst) {
      if (p.equals(sp, bookPath) ||
          p.isWithin(sp, bookPath) ||
          bookPath.startsWith(sp)) {
        return sp;
      }
    }
    return null;
  }

  void _sortDirectoryTree(_DirectoryNode node) {
    node.books.sort((a, b) {
      final titleA = (a as dynamic).title as String? ?? '';
      final titleB = (b as dynamic).title as String? ?? '';
      final seqA = (a as dynamic).seriesSequence as String?;
      final seqB = (b as dynamic).seriesSequence as String?;
      if (seqA != null && seqB != null) {
        final numA = double.tryParse(seqA);
        final numB = double.tryParse(seqB);
        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = _naturalCompare(seqA, seqB);
          if (cmp != 0) return cmp;
        }
      } else if (seqA != null) {
        return -1;
      } else if (seqB != null) {
        return 1;
      }
      return _naturalCompare(titleA, titleB);
    });

    for (final child in node.subdirectories.values) {
      _sortDirectoryTree(child);
    }
  }

  Widget _buildDirectoryNodeWidget(
    BuildContext context,
    HomeState state,
    _DirectoryNode node,
    int depth,
  ) {
    final subDirs = node.subdirectories.values.toList()
      ..sort((a, b) => _naturalCompare(a.name, b.name));

    final childrenWidgets = <Widget>[];

    for (final sub in subDirs) {
      childrenWidgets.add(
        _buildDirectoryNodeWidget(context, state, sub, depth + 1),
      );
    }

    for (final book in node.books) {
      if (book is Audiobook) {
        childrenWidgets.add(
          _buildAudiobookTile(context, state, book),
        );
      } else {
        childrenWidgets.add(
          _buildEbookTile(context, state, book),
        );
      }
    }

    if (node.name == 'Root') {
      if (childrenWidgets.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: childrenWidgets,
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: depth <= 1,
        tilePadding: EdgeInsets.only(
          left: 12.0 + 12.0 * (depth > 0 ? depth - 1 : 0),
          right: 16,
        ),
        leading: Icon(
          Icons.folder,
          color: depth == 1
              ? const Color(0xFFE8B86D)
              : const Color(0xFFE8B86D).withValues(alpha: 0.75),
          size: depth == 1 ? 24 : 22,
        ),
        title: Text(
          node.name,
          style: TextStyle(
            color: depth == 1 ? const Color(0xFFE8B86D) : Colors.white70,
            fontWeight: depth == 1 ? FontWeight.bold : FontWeight.w600,
            fontSize: depth == 1 ? 17 : 15,
          ),
        ),
        children: childrenWidgets,
      ),
    );
  }
}

class _DirectoryNode {
  final String name;
  final Map<String, _DirectoryNode> subdirectories = {};
  final List<dynamic> books = [];

  _DirectoryNode(this.name);
}
