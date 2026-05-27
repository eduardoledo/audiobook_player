import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audiobook.dart';
import '../services/audio_player_service.dart';

class PlayerScreen extends StatefulWidget {
  final Audiobook audiobook;

  const PlayerScreen({super.key, required this.audiobook});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AudioPlayerService _playerService;
  bool _showChapters = false;

  @override
  void initState() {
    super.initState();
    _playerService = AudioPlayerService();
    _playerService.setAudiobook(widget.audiobook);
    _playerService.play();
  }

  @override
  void dispose() {
    _playerService.dispose();
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
            icon: Icon(_showChapters ? Icons.expand_less : Icons.list),
            onPressed: () => setState(() => _showChapters = !_showChapters),
            tooltip: _showChapters ? 'Hide chapters' : 'Show chapters',
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
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildProgress(),
                  const SizedBox(height: 24),
                  _buildControls(),
                  if (_showChapters) ...[
                    const SizedBox(height: 32),
                    _buildChaptersList(),
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
        color: const Color(0xFFE8B86D).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
            final duration = durationSnapshot.data ?? Duration.zero;
            final totalMs = duration.inMilliseconds;
            final posMs = position.inMilliseconds;
            final progress = totalMs > 0 ? posMs / totalMs : 0.0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE8B86D),
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: const Color(0xFFE8B86D),
                  ),
                  child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    if (totalMs > 0) {
                      _playerService.seekToPosition(
                        Duration(milliseconds: (v * totalMs).round()),
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
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
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

  Widget _buildChaptersList() {
    return StreamBuilder<Duration>(
      stream: _playerService.positionStream,
      builder: (context, snapshot) {
        final currentIndex =
            _playerService.getCurrentChapterIndex(widget.audiobook);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chapters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: widget.audiobook.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.audiobook.chapters[index];
                    final isCurrent = currentIndex == index;

                    return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.play_arrow, color: Colors.white54, size: 20),
                  onTap: () {
                    _playerService.seekToChapter(widget.audiobook, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
