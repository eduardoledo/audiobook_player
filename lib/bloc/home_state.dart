import 'package:equatable/equatable.dart';
import '../models/audiobook.dart';
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
  final List<Playlist> playlists;
  final bool isLoading;
  final bool isScanning;
  final double? scanProgress;
  final String? error;
  final Map<String, BookFetchStatus> fetchingMetadata;
  final int metadataFetchTotalCount;

  const HomeState({
    this.scanPaths = const [],
    this.audiobooks = const [],
    this.playlists = const [],
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
    List<Playlist>? playlists,
    bool? isLoading,
    bool? isScanning,
    double? scanProgress,
    String? error,
    Map<String, BookFetchStatus>? fetchingMetadata,
    int? metadataFetchTotalCount,
  }) {
    return HomeState(
      scanPaths: scanPaths ?? this.scanPaths,
      audiobooks: audiobooks ?? this.audiobooks,
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      error: error ?? this.error,
      fetchingMetadata: fetchingMetadata ?? this.fetchingMetadata,
      metadataFetchTotalCount: metadataFetchTotalCount ?? this.metadataFetchTotalCount,
    );
  }

  HomeState clearError() {
    return HomeState(
      scanPaths: scanPaths,
      audiobooks: audiobooks,
      playlists: playlists,
      isLoading: isLoading,
      isScanning: isScanning,
      scanProgress: scanProgress,
      error: null,
      fetchingMetadata: fetchingMetadata,
      metadataFetchTotalCount: metadataFetchTotalCount,
    );
  }

  @override
  List<Object?> get props => [
        scanPaths,
        audiobooks,
        playlists,
        isLoading,
        isScanning,
        scanProgress,
        error,
        fetchingMetadata,
        metadataFetchTotalCount,
      ];
}
