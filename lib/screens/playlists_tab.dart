import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final playlists = state.playlists;

        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.playlist_play, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No playlists yet.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final p = playlists[index];
            return Card(
              color: const Color(0xFF252525),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${p.bookPaths.length} books', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  onPressed: () => context.read<HomeCubit>().deletePlaylist(p.id!),
                ),
                onTap: () {
                  // Show books in playlist
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1A1A1A),
                    builder: (context) {
                      final playlistBooks = state.audiobooks.where((b) => p.bookPaths.contains(b.path)).toList();
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: playlistBooks.length,
                              itemBuilder: (context, i) {
                                final book = playlistBooks[i];
                                return ListTile(
                                  title: Text(book.title, style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(book.author, style: const TextStyle(color: Colors.white54)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                                    onPressed: () {
                                      context.read<HomeCubit>().removeBookFromPlaylist(p.id!, book.path);
                                      Navigator.pop(context); // close sheet to refresh
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
