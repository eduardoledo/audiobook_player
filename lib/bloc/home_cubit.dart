import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/audiobook.dart';
import '../service_locator.dart';
import '../services/audiobook_scanner.dart';
import '../services/library_storage.dart';
import '../services/metadata_fetcher.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final LibraryStorage _storage = getIt<LibraryStorage>();
  final AudiobookScanner _scanner = getIt<AudiobookScanner>();
  
  StreamSubscription? _scanSubscription;

  HomeCubit() : super(const HomeState()) {
    _initFetcher();
    loadData();
  }

  Future<void> _initFetcher() async {
    await MetadataFetcher.start((updatedBook) async {
      if (isClosed) return;
      
      final currentBooks = List<Audiobook>.from(state.audiobooks);
      final index = currentBooks.indexWhere((b) => b.path == updatedBook.path);
      if (index != -1) {
        currentBooks[index] = updatedBook;
        
        final newFetching = Set<String>.from(state.fetchingPaths)..remove(updatedBook.path);
        
        emit(state.copyWith(audiobooks: currentBooks, fetchingPaths: newFetching));
        // Persist the changes
        await _storage.saveAudiobooks(currentBooks);
      }
    });
  }

  @override
  Future<void> close() {
    MetadataFetcher.stop();
    _scanSubscription?.cancel();
    return super.close();
  }

  Future<void> loadData() async {
    emit(state.copyWith(isLoading: true).clearError());
    try {
      final paths = await _storage.getScanPaths();
      final books = await _storage.getAudiobooks();
      final playlists = await _storage.getPlaylists();
      emit(state.copyWith(
        scanPaths: paths,
        audiobooks: books,
        playlists: playlists,
        isLoading: false,
      ));
      
      // Enqueue books that need metadata
      MetadataFetcher.enqueue(books);
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> scanDirectory(String path) async {
    emit(state.copyWith(isScanning: true, scanProgress: 0.0).clearError());

    try {
      await _storage.addScanPath(path);
      
      final currentPaths = List<String>.from(state.scanPaths);
      if (!currentPaths.contains(path)) {
        currentPaths.add(path);
      }
      
      emit(state.copyWith(scanPaths: currentPaths));

      final seriesRules = await _storage.getSeriesMappingRules();
      final stream = _scanner.scanDirectoryStream(path, skipPaths: {}, seriesRules: seriesRules);
      
      _scanSubscription = stream.listen(
        (message) {
          if (isClosed) return;

          List<Audiobook>? newAudiobooks;
          if (message.audiobook != null) {
            final currentBooks = List<Audiobook>.from(state.audiobooks);
            final index = currentBooks.indexWhere((b) => b.path == message.audiobook!.path);
            if (index != -1) {
               // Preserve local metadata flags while replacing
               final oldBook = currentBooks[index];
               currentBooks[index] = message.audiobook!.copyWith(
                 hasMetadataLocally: oldBook.hasMetadataLocally,
                 publishYear: oldBook.publishYear,
                 description: oldBook.description,
                 subjects: oldBook.subjects,
                 coverPath: oldBook.coverPath,
                 series: oldBook.series,
               );
            } else {
               currentBooks.add(message.audiobook!);
            }
            newAudiobooks = currentBooks;
          }

          emit(state.copyWith(
            audiobooks: newAudiobooks,
            scanProgress: message.progress,
          ));
        },
        onDone: () async {
          await _storage.saveAudiobooks(state.audiobooks);
          MetadataFetcher.enqueue(state.audiobooks);
          emit(state.copyWith(isScanning: false, scanProgress: null));
          _scanSubscription = null;
        },
        onError: (e) {
          emit(state.copyWith(error: e.toString(), isScanning: false, scanProgress: null));
          _scanSubscription = null;
        },
      );

    } catch (e) {
      emit(state.copyWith(error: e.toString(), isScanning: false, scanProgress: null));
    }
  }

  Future<void> rescanAll() async {
    emit(state.copyWith(isScanning: true, scanProgress: 0.0).clearError());

    try {
      final allBooks = List<Audiobook>.from(state.audiobooks);
      
      // Simple wrapper to run scans sequentially
      for (int i = 0; i < state.scanPaths.length; i++) {
        final path = state.scanPaths[i];
        if (await Directory(path).exists()) {
          final seriesRules = await _storage.getSeriesMappingRules();
          final stream = _scanner.scanDirectoryStream(path, skipPaths: {}, seriesRules: seriesRules);
          
          final completer = Completer<void>();
          _scanSubscription = stream.listen(
            (message) {
              if (isClosed) return;
              if (message.audiobook != null) {
                final index = allBooks.indexWhere((b) => b.path == message.audiobook!.path);
                if (index != -1) {
                   final oldBook = allBooks[index];
                   allBooks[index] = message.audiobook!.copyWith(
                     hasMetadataLocally: oldBook.hasMetadataLocally,
                     publishYear: oldBook.publishYear,
                     description: oldBook.description,
                     subjects: oldBook.subjects,
                     coverPath: oldBook.coverPath,
                     series: oldBook.series,
                   );
                } else {
                   allBooks.add(message.audiobook!);
                }
              }
              
              // Progress reflects the overall paths progress + individual path progress
              final overallProgress = (i + (message.progress ?? 0.0)) / state.scanPaths.length;
              
              emit(state.copyWith(
                audiobooks: List.from(allBooks),
                scanProgress: overallProgress,
              ));
            },
            onDone: () => completer.complete(),
            onError: (e) {
              emit(state.copyWith(error: e.toString()));
              completer.complete();
            },
          );
          
          await completer.future;
          if (!state.isScanning) break; // Check if cancelled
        }
      }
      
      await _storage.saveAudiobooks(state.audiobooks);
      MetadataFetcher.enqueue(state.audiobooks);
      emit(state.copyWith(isScanning: false, scanProgress: null));
      _scanSubscription = null;
      
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isScanning: false, scanProgress: null));
    }
  }

  void cancelScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    emit(state.copyWith(isScanning: false, scanProgress: null));
  }

  Future<void> removePath(String path) async {
    if (state.isScanning) return;
    
    emit(state.copyWith(isLoading: true).clearError());
    try {
      await _storage.removeScanPath(path);
      
      final remainingPaths = state.scanPaths.where((p) => p != path).toList();
      final remainingBooks = state.audiobooks.where((b) {
        return remainingPaths.any((p) =>
            b.path == p || b.path.startsWith('$p${Platform.pathSeparator}'));
      }).toList();
      
      await _storage.saveAudiobooks(remainingBooks);
      
      emit(state.copyWith(
        scanPaths: remainingPaths,
        audiobooks: remainingBooks,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> forceFetchMetadata(Audiobook book) async {
    final newFetching = Set<String>.from(state.fetchingPaths)..add(book.path);
    emit(state.copyWith(fetchingPaths: newFetching));

    try {
      final metaFile = File('${book.path}${Platform.pathSeparator}metadata.json');
      final coverFile = File('${book.path}${Platform.pathSeparator}cover.jpg');
      
      if (await metaFile.exists()) await metaFile.delete();
      if (await coverFile.exists()) await coverFile.delete();
      
      MetadataFetcher.enqueue([book.copyWith(hasMetadataLocally: false)]);
    } catch (e) {
      final revertedFetching = Set<String>.from(state.fetchingPaths)..remove(book.path);
      emit(state.copyWith(fetchingPaths: revertedFetching, error: 'Failed to force fetch: $e'));
    }
  }

  // --- Playlists ---

  Future<void> createPlaylist(String name) async {
    try {
      await _storage.createPlaylist(name);
      final playlists = await _storage.getPlaylists();
      emit(state.copyWith(playlists: playlists));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deletePlaylist(int id) async {
    try {
      await _storage.deletePlaylist(id);
      final playlists = await _storage.getPlaylists();
      emit(state.copyWith(playlists: playlists));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> addBookToPlaylist(int playlistId, String bookPath) async {
    try {
      await _storage.addBookToPlaylist(playlistId, bookPath);
      final playlists = await _storage.getPlaylists();
      emit(state.copyWith(playlists: playlists));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> removeBookFromPlaylist(int playlistId, String bookPath) async {
    try {
      await _storage.removeBookFromPlaylist(playlistId, bookPath);
      final playlists = await _storage.getPlaylists();
      emit(state.copyWith(playlists: playlists));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
