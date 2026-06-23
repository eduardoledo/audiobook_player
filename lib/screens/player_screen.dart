import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audiobook.dart';
import '../models/bookmark.dart';
import '../service_locator.dart';
import '../services/audio_player_service.dart';
import '../services/library_storage.dart';
import '../services/metadata_fetcher.dart';

class PlayerScreen extends StatefulWidget {
  final Audiobook audiobook;

  const PlayerScreen({super.key, required this.audiobook});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AudioPlayerService _playerService;
  late final LibraryStorage _storage;
  bool _showChapters = false;
  List<Bookmark> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _storage = getIt<LibraryStorage>();
    _playerService = getIt<AudioPlayerService>();
    
    _initPlayer();
    _loadBookmarks();
    
    // Prioritize API fetch for this book when opened
    MetadataFetcher.enqueue([widget.audiobook.copyWith(hasMetadataLocally: false)]);
  }

  Future<void> _initPlayer() async {
    final progress = await _storage.getPlaybackProgress(widget.audiobook.path);
    final chapterIndex = progress?['chapterIndex'] ?? 0;
    final positionMs = progress?['positionMs'] ?? 0;
    
    await _playerService.setAudiobook(
      widget.audiobook, 
      chapterIndex: chapterIndex, 
      position: Duration(milliseconds: positionMs),
    );
    _playerService.play();
  }

  Future<void> _loadBookmarks() async {
    final b = await _storage.getBookmarks(widget.audiobook.path);
    if (mounted) setState(() => _bookmarks = b);
  }

  Future<void> _addBookmark() async {
    final posMs = _playerService.position.inMilliseconds;
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Add Bookmark', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Note (optional)',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8B86D))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save', style: TextStyle(color: Color(0xFFE8B86D))),
          ),
        ],
      ),
    );
    
    if (label != null) {
      await _storage.addBookmark(widget.audiobook.path, posMs, label.isEmpty ? null : label);
      await _loadBookmarks();
      setState(() => _showChapters = true);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(
          widget.audiobook.title,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
            tooltip: 'Add bookmark',
          ),
          IconButton(
            icon: Icon(_showChapters ? Icons.expand_less : Icons.list),
            onPressed: () => setState(() => _showChapters = !_showChapters),
            tooltip: _showChapters ? 'Hide list' : 'Show list',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildCover(),
                  const SizedBox(height: 32),
                  Text(
                    widget.audiobook.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.audiobook.author,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildProgress(),
                  const SizedBox(height: 24),
                  _buildControls(),
                  if (_showChapters) ...[
                    const SizedBox(height: 32),
                    _buildListSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFE8B86D).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.audiotrack, size: 80, color: Color(0xFFE8B86D)),
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<Duration>(
      stream: _playerService.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _playerService.durationStream,
          builder: (context, durationSnapshot) {
            final chapterDuration = durationSnapshot.data ?? Duration.zero;
            final chapterTotalMs = chapterDuration.inMilliseconds;
            final chapterPosMs = position.inMilliseconds;
            final chapterProgress = chapterTotalMs > 0 ? chapterPosMs / chapterTotalMs : 0.0;
            
            final currentIndex = _playerService.getCurrentChapterIndex(widget.audiobook) ?? 0;
            
            double previousChaptersSeconds = 0.0;
            for (int i = 0; i < currentIndex && i < widget.audiobook.chapters.length; i++) {
               previousChaptersSeconds += widget.audiobook.chapters[i].duration;
            }
            final totalBookSeconds = widget.audiobook.chapters.fold<double>(0.0, (sum, c) => sum + c.duration);
            
            final bookPosMs = (previousChaptersSeconds * 1000).round() + chapterPosMs;
            final bookTotalMs = (totalBookSeconds * 1000).round();
            final bookProgress = bookTotalMs > 0 ? bookPosMs / bookTotalMs : 0.0;

            return Column(
              children: [
                // Total Book Progress Bar
                if (widget.audiobook.chapters.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                         const Text('Total Book', style: TextStyle(color: Colors.white54, fontSize: 10)),
                         const SizedBox(width: 8),
                         Expanded(
                           child: LinearProgressIndicator(
                             value: bookProgress.clamp(0.0, 1.0),
                             backgroundColor: Colors.white.withValues(alpha: 0.1),
                             valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFE8B86D).withValues(alpha: 0.6)),
                             minHeight: 3,
                             borderRadius: BorderRadius.circular(2),
                           ),
                         ),
                         const SizedBox(width: 8),
                         Text(_formatDuration(Duration(milliseconds: bookTotalMs)), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ]
                    ),
                  ),
                const SizedBox(height: 8),
                // Chapter Progress Bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE8B86D),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: const Color(0xFFE8B86D),
                  ),
                  child: Slider(
                    value: chapterProgress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      if (chapterTotalMs > 0) {
                        _playerService.seekToPosition(
                          Duration(milliseconds: (v * chapterTotalMs).round()),
                        );
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(chapterDuration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControls() {
    return StreamBuilder<PlayerState>(
      stream: _playerService.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PlayerState(false, ProcessingState.idle);
        final isPlaying = state.playing;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, size: 36),
              color: Colors.white70,
              onPressed: () {
                final pos = _playerService.position;
                _playerService.seekToPosition(
                  Duration(seconds: (pos.inSeconds - 10).clamp(0, pos.inSeconds)),
                );
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 64,
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 64,
              ),
              color: const Color(0xFFE8B86D),
              onPressed: () {
                if (isPlaying) {
                  _playerService.pause();
                } else {
                  _playerService.play();
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10, size: 36),
              color: Colors.white70,
              onPressed: () {
                final pos = _playerService.position;
                final dur = _playerService.duration ?? Duration.zero;
                _playerService.seekToPosition(
                  Duration(
                    seconds: (pos.inSeconds + 10).clamp(0, dur.inSeconds),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildListSection() {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFFE8B86D),
              labelColor: Color(0xFFE8B86D),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Chapters'),
                Tab(text: 'Bookmarks'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildChaptersTab(),
                  _buildBookmarksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarksTab() {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Text(
          'No bookmarks yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final b = _bookmarks[index];
        return ListTile(
          title: Text(
            b.label ?? 'Bookmark ${index + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            b.positionFormatted,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
            onPressed: () async {
              if (b.id != null) {
                await _storage.removeBookmark(b.id!);
                _loadBookmarks();
              }
            },
          ),
          onTap: () {
            _playerService.seekToPosition(Duration(milliseconds: b.positionMs));
          },
        );
      },
    );
  }

  Widget _buildChaptersTab() {
    return StreamBuilder<Duration>(
      stream: _playerService.positionStream,
      builder: (context, snapshot) {
        final currentIndex = _playerService.getCurrentChapterIndex(widget.audiobook) ?? 0;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: widget.audiobook.chapters.length,
          itemBuilder: (context, index) {
            final chapter = widget.audiobook.chapters[index];
            final isCurrent = currentIndex == index;

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                chapter.displayTitle,
                style: TextStyle(
                  color: isCurrent ? const Color(0xFFE8B86D) : Colors.white,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                chapter.startFormatted,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.play_arrow, color: Colors.white54, size: 20),
              onTap: () {
                _playerService.seekToChapter(widget.audiobook, index);
              },
            );
          },
        );
      },
    );
  }
}
