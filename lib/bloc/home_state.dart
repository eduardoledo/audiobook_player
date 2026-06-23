import 'package:equatable/equatable.dart';
import '../models/audiobook.dart';
import '../models/playlist.dart';

class HomeState extends Equatable {
  final List<String> scanPaths;
  final List<Audiobook> audiobooks;
  final List<Playlist> playlists;
  final bool isLoading;
  final bool isScanning;
  final double? scanProgress;
  final String? error;
  final Set<String> fetchingPaths;

  const HomeState({
    this.scanPaths = const [],
    this.audiobooks = const [],
    this.playlists = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.scanProgress,
    this.error,
    this.fetchingPaths = const {},
  });

  HomeState copyWith({
    List<String>? scanPaths,
    List<Audiobook>? audiobooks,
    List<Playlist>? playlists,
    bool? isLoading,
    bool? isScanning,
    double? scanProgress,
    String? error,
    Set<String>? fetchingPaths,
  }) {
    return HomeState(
      scanPaths: scanPaths ?? this.scanPaths,
      audiobooks: audiobooks ?? this.audiobooks,
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      error: error ?? this.error,
      fetchingPaths: fetchingPaths ?? this.fetchingPaths,
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
      fetchingPaths: fetchingPaths,
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
        fetchingPaths,
      ];
}
