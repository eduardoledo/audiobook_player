import 'package:equatable/equatable.dart';
import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../models/playlist.dart';

class BookFetchStatus extends Equatable {
  final String status;
  final double progress;
  const BookFetchStatus({required this.status, required this.progress});

  @override
  List<Object?> get props => [status, progress];
}

class HomeState extends Equatable {
  final List<String> scanPaths;
  final List<Audiobook> audiobooks;
  final List<Ebook> ebooks;
  final List<Playlist> playlists;
  final int? activePlaylistId;
  final bool isLoading;
  final bool isScanning;
  final double? scanProgress;
  final String? error;
  final Map<String, BookFetchStatus> fetchingMetadata;
  final int metadataFetchTotalCount;

  const HomeState({
    this.scanPaths = const [],
    this.audiobooks = const [],
    this.ebooks = const [],
    this.playlists = const [],
    this.activePlaylistId,
    this.isLoading = false,
    this.isScanning = false,
    this.scanProgress,
    this.error,
    this.fetchingMetadata = const {},
    this.metadataFetchTotalCount = 0,
  });

  HomeState copyWith({
    List<String>? scanPaths,
    List<Audiobook>? audiobooks,
    List<Ebook>? ebooks,
    List<Playlist>? playlists,
    int? activePlaylistId,
    bool? isLoading,
    bool? isScanning,
    double? scanProgress,
    String? error,
    Map<String, BookFetchStatus>? fetchingMetadata,
    int? metadataFetchTotalCount,
    bool clearActivePlaylist = false,
  }) {
    return HomeState(
      scanPaths: scanPaths ?? this.scanPaths,
      audiobooks: audiobooks ?? this.audiobooks,
      ebooks: ebooks ?? this.ebooks,
      playlists: playlists ?? this.playlists,
      activePlaylistId: clearActivePlaylist ? null : (activePlaylistId ?? this.activePlaylistId),
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      error: error ?? this.error,
      fetchingMetadata: fetchingMetadata ?? this.fetchingMetadata,
      metadataFetchTotalCount: metadataFetchTotalCount ?? this.metadataFetchTotalCount,
    );
  }

  HomeState clearError() {
    return copyWith(error: null);
  }

  @override
  List<Object?> get props => [
        scanPaths,
        audiobooks,
        ebooks,
        playlists,
        activePlaylistId,
        isLoading,
        isScanning,
        scanProgress,
        error,
        fetchingMetadata,
        metadataFetchTotalCount,
      ];
}
