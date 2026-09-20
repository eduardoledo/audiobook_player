import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../models/playlist.dart';
import '../models/scan_message.dart';
import '../service_locator.dart';
import '../services/audiobook_scanner.dart';
import '../services/library_storage.dart';
import '../services/metadata_fetcher.dart';
import '../services/ebook_metadata_fetcher.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final LibraryStorage _storage = getIt<LibraryStorage>();
  final AudiobookScanner _scanner = getIt<AudiobookScanner>();
  
  StreamSubscription<ScanMessage>? _scanSubscription;

  HomeCubit() : super(const HomeState()) {
    _initFetcher();
    _initEbookFetcher();
    loadData();
  }

  Future<void> _initFetcher() async {
    await MetadataFetcher.start(
      onMetadataFetched: (updatedBook) async {
        if (isClosed) return;
        
        final currentBooks = List<Audiobook>.from(state.audiobooks);
        final index = currentBooks.indexWhere((b) => b.path == updatedBook.path);
        if (index != -1) {
          currentBooks[index] = updatedBook;
          
          final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(updatedBook.path);
          final newTotal = newFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
          
          emit(state.copyWith(
            audiobooks: currentBooks,
            fetchingMetadata: newFetching,
            metadataFetchTotalCount: newTotal,
          ));
          // Persist the changes
          await _storage.saveAudiobooks(currentBooks);
        }
      },
      onProgress: (path, status, progress) {
        if (isClosed) return;
        final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)
          ..[path] = BookFetchStatus(status: status, progress: progress);
        emit(state.copyWith(fetchingMetadata: newFetching));
      },
      onFetchError: (path, error) {
        if (isClosed) return;
        final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(path);
        final newTotal = newFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
        emit(state.copyWith(fetchingMetadata: newFetching, error: error, metadataFetchTotalCount: newTotal));
      },
    );
  }

  Future<void> _initEbookFetcher() async {
    await EbookMetadataFetcher.start(
      onMetadataFetched: (updatedBook) async {
        if (isClosed) return;
        
        final currentEbooks = List<Ebook>.from(state.ebooks);
        final index = currentEbooks.indexWhere((b) => b.file == updatedBook.file);
        if (index != -1) {
          currentEbooks[index] = updatedBook;
          
          final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(updatedBook.file);
          final newTotal = newFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
          
          emit(state.copyWith(
            ebooks: currentEbooks,
            fetchingMetadata: newFetching,
            metadataFetchTotalCount: newTotal,
          ));
          // Persist the changes
          await _storage.saveEbooks(currentEbooks);
        }
      },
      onProgress: (path, status, progress) {
        if (isClosed) return;
        final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)
          ..[path] = BookFetchStatus(status: status, progress: progress);
        emit(state.copyWith(fetchingMetadata: newFetching));
      },
      onFetchError: (path, error) {
        if (isClosed) return;
        final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(path);
        final newTotal = newFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
        emit(state.copyWith(fetchingMetadata: newFetching, error: error, metadataFetchTotalCount: newTotal));
      },
    );
  }

  @override
  Future<void> close() {
    MetadataFetcher.stop();
    EbookMetadataFetcher.stop();
    _scanSubscription?.cancel();
    return super.close();
  }

  void _enqueueBooks(List<Audiobook> books) {
    final booksToFetch = books.where((b) => !b.hasMetadataLocally || b.durationFormatted == '00:00:00.000').toList();
    if (booksToFetch.isEmpty) return;
    
    final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata);
    for (final b in booksToFetch) {
      newFetching[b.path] = const BookFetchStatus(status: "Queued...", progress: 0.0);
    }
    
    final newTotal = state.fetchingMetadata.isEmpty 
        ? booksToFetch.length 
        : state.metadataFetchTotalCount + booksToFetch.length;

    emit(state.copyWith(fetchingMetadata: newFetching, metadataFetchTotalCount: newTotal));
    MetadataFetcher.enqueue(booksToFetch);
  }

  /// Enqueues online metadata fetch for a book (used after user confirmation).
  void enqueueMetadataFetch(Audiobook book) {
    _enqueueBooks([book]);
  }

  /// Marks that the user declined online metadata so we do not ask again on open.
  /// Manual "Refresh Metadata" can still force a fetch later.
  Future<void> skipOnlineMetadata(Audiobook book) async {
    final currentBooks = List<Audiobook>.from(state.audiobooks);
    final index = currentBooks.indexWhere((b) => b.path == book.path);
    if (index == -1) return;

    final updated = currentBooks[index].copyWith(hasMetadataLocally: true);
    currentBooks[index] = updated;
    emit(state.copyWith(audiobooks: currentBooks));
    await _storage.saveAudiobooks(currentBooks);
  }

  void _enqueueEbooks(List<Ebook> ebooks) {
    final ebooksToFetch = ebooks.where((b) => !b.hasMetadataLocally).toList();
    if (ebooksToFetch.isEmpty) return;
    
    final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata);
    for (final b in ebooksToFetch) {
      newFetching[b.file] = const BookFetchStatus(status: "Queued...", progress: 0.0);
    }
    
    final newTotal = state.fetchingMetadata.isEmpty 
        ? ebooksToFetch.length 
        : state.metadataFetchTotalCount + ebooksToFetch.length;

    emit(state.copyWith(fetchingMetadata: newFetching, metadataFetchTotalCount: newTotal));
    EbookMetadataFetcher.enqueue(ebooksToFetch);
  }

  Future<void> loadData() async {
    emit(state.copyWith(isLoading: true).clearError());
    try {
      final paths = await _storage.getScanPaths();
      final books = await _storage.getAudiobooks();
      final ebooks = await _storage.getEbooks();
      final categories = await _storage.getAllCategories();
      final playlists = await _storage.getPlaylists();
      final viewMode = await _storage.getLibraryViewMode();
      emit(state.copyWith(
        scanPaths: paths,
        audiobooks: books,
        ebooks: ebooks,
        categories: categories,
        playlists: playlists,
        viewMode: viewMode,
        isLoading: false,
      ));
      
      // Automatic metadata update on load disabled to prevent unrequested internet fetches
      // _enqueueBooks(books);
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> setViewMode(String mode) async {
    emit(state.copyWith(viewMode: mode));
    await _storage.saveLibraryViewMode(mode);
  }

  Future<void> toggleViewMode() async {
    final nextMode = state.viewMode == 'grid' ? 'list' : 'grid';
    await setViewMode(nextMode);
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
          List<Ebook>? newEbooks;
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
                 seriesSequence: oldBook.seriesSequence,
                 universe: oldBook.universe,
                 isRead: oldBook.isRead,
               );
            } else {
               currentBooks.add(message.audiobook!);
            }
            newAudiobooks = currentBooks;
          }
          if (message.ebook != null) {
            final currentEbooks = List<Ebook>.from(state.ebooks);
            final index = currentEbooks.indexWhere((b) => b.file == message.ebook!.file);
            if (index != -1) {
              currentEbooks[index] = message.ebook!;
            } else {
              currentEbooks.add(message.ebook!);
            }
            newEbooks = currentEbooks;
          }

          emit(state.copyWith(
            audiobooks: newAudiobooks,
            ebooks: newEbooks,
            scanProgress: message.progress,
          ));
        },
        onDone: () async {
          // Sync categories from all relative book paths
          final scanPaths = await _storage.getScanPaths();
          final List<String> relativePaths = [];
          for (final b in state.audiobooks) {
            for (final sp in scanPaths) {
              if (b.path.startsWith(sp)) {
                relativePaths.add(p.relative(b.path, from: sp));
                break;
              }
            }
          }
          for (final e in state.ebooks) {
            for (final sp in scanPaths) {
              if (e.file.startsWith(sp)) {
                relativePaths.add(p.relative(e.file, from: sp));
                break;
              }
            }
          }

          final categoryMap = await _storage.syncCategoriesFromBookPaths(relativePaths);

          // Update audiobooks and ebooks with assigned categoryId
          final updatedAudiobooks = state.audiobooks.map((b) {
            String? bookRel;
            for (final sp in scanPaths) {
              if (b.path.startsWith(sp)) {
                bookRel = p.relative(b.path, from: sp);
                break;
              }
            }
            if (bookRel != null) {
              final parentPrefix = p.dirname(bookRel);
              if (parentPrefix != '.' && categoryMap.containsKey(parentPrefix)) {
                return b.copyWith(categoryId: categoryMap[parentPrefix]);
              }
            }
            return b;
          }).toList();

          final updatedEbooks = state.ebooks.map((e) {
            String? bookRel;
            for (final sp in scanPaths) {
              if (e.file.startsWith(sp)) {
                bookRel = p.relative(e.file, from: sp);
                break;
              }
            }
            if (bookRel != null) {
              final parentPrefix = p.dirname(bookRel);
              if (parentPrefix != '.' && categoryMap.containsKey(parentPrefix)) {
                return e.copyWith(categoryId: categoryMap[parentPrefix]);
              }
            }
            return e;
          }).toList();

          final categories = await _storage.getAllCategories();

          await _storage.saveAudiobooks(updatedAudiobooks);
          await _storage.saveEbooks(updatedEbooks);
          
          final authors = <String>{};
          final sagas = <String>{};
          for (final b in updatedAudiobooks) {
            if (b.author != 'Unknown') authors.add(b.author);
            if (b.series != null) sagas.add(b.series!);
          }
          for (final b in updatedEbooks) {
            if (b.author != 'Unknown') authors.add(b.author);
            if (b.series != null) sagas.add(b.series!);
          }
          await _storage.saveAuthors(authors);
          await _storage.saveSagas(sagas);

          emit(state.copyWith(
            audiobooks: updatedAudiobooks,
            ebooks: updatedEbooks,
            categories: categories,
            isScanning: false,
            scanProgress: null,
          ));
          _scanSubscription = null;
        },
        onError: (Object e) {
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
      final allEbooks = List<Ebook>.from(state.ebooks);
      
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
                     seriesSequence: oldBook.seriesSequence,
                     universe: oldBook.universe,
                     isRead: oldBook.isRead,
                   );
                } else {
                   allBooks.add(message.audiobook!);
                }
              }
              if (message.ebook != null) {
                final index = allEbooks.indexWhere((b) => b.file == message.ebook!.file);
                if (index != -1) {
                  allEbooks[index] = message.ebook!;
                } else {
                  allEbooks.add(message.ebook!);
                }
              }
              
              // Progress reflects the overall paths progress + individual path progress
              final overallProgress = (i + (message.progress ?? 0.0)) / state.scanPaths.length;
              
              emit(state.copyWith(
                audiobooks: List.from(allBooks),
                ebooks: List.from(allEbooks),
                scanProgress: overallProgress,
              ));
            },
            onDone: () => completer.complete(),
            onError: (Object e) {
              emit(state.copyWith(error: e.toString()));
              completer.complete();
            },
          );
          
          await completer.future;
          if (!state.isScanning) break; // Check if cancelled
        }
      }
      
      await _storage.saveAudiobooks(state.audiobooks);
      await _storage.saveEbooks(state.ebooks);

      final authors = <String>{};
      final sagas = <String>{};
      for (final b in state.audiobooks) {
        if (b.author != 'Unknown') authors.add(b.author);
        if (b.series != null) sagas.add(b.series!);
      }
      for (final b in state.ebooks) {
        if (b.author != 'Unknown') authors.add(b.author);
        if (b.series != null) sagas.add(b.series!);
      }
      await _storage.saveAuthors(authors);
      await _storage.saveSagas(sagas);

      // Automatic metadata update on rescan completion disabled to prevent unrequested internet fetches
      // _enqueueBooks(state.audiobooks);
      emit(state.copyWith(isScanning: false, scanProgress: null));
      _scanSubscription = null;
      
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isScanning: false, scanProgress: null));
    }
  }

  Future<void> toggleReadStatus(Audiobook book) async {
    final currentBooks = List<Audiobook>.from(state.audiobooks);
    final index = currentBooks.indexWhere((b) => b.path == book.path);
    if (index != -1) {
      final updatedBook = book.copyWith(isRead: !book.isRead);
      currentBooks[index] = updatedBook;
      emit(state.copyWith(audiobooks: currentBooks));
      await _storage.saveAudiobooks(currentBooks);
    }
  }

  Future<void> markAsRead(Audiobook book) async {
    if (book.isRead) return;
    final currentBooks = List<Audiobook>.from(state.audiobooks);
    final index = currentBooks.indexWhere((b) => b.path == book.path);
    if (index == -1) return;
    currentBooks[index] = currentBooks[index].copyWith(isRead: true);
    emit(state.copyWith(audiobooks: currentBooks));
    await _storage.saveAudiobooks(currentBooks);
  }

  void cancelScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    emit(state.copyWith(isScanning: false, scanProgress: null));
  }

  void cancelMetadataFetch() {
    MetadataFetcher.clearQueue();
    emit(state.copyWith(
      fetchingMetadata: {},
      metadataFetchTotalCount: 0,
    ));
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
    final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)
      ..[book.path] = const BookFetchStatus(status: "Initializing...", progress: 0.0);
    final newTotal = state.fetchingMetadata.isEmpty ? 1 : state.metadataFetchTotalCount + 1;
    emit(state.copyWith(fetchingMetadata: newFetching, metadataFetchTotalCount: newTotal));

    try {
      final bookMeta = File(p.join(book.path, 'book.metadata.json'));
      final legacyMeta = File(p.join(book.path, 'metadata.json'));
      final coverFile = File(p.join(book.path, 'cover.jpg'));
      
      if (await bookMeta.exists()) await bookMeta.delete();
      if (await legacyMeta.exists()) await legacyMeta.delete();
      if (await coverFile.exists()) await coverFile.delete();
      
      _enqueueBooks([book.copyWith(hasMetadataLocally: false)]);
    } catch (e) {
      final revertedFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(book.path);
      final newTotal = revertedFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
      emit(state.copyWith(fetchingMetadata: revertedFetching, error: 'Failed to force fetch: $e', metadataFetchTotalCount: newTotal));
    }
  }

  Future<void> forceFetchEbookMetadata(Ebook book) async {
    final newFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)
      ..[book.file] = const BookFetchStatus(status: "Initializing...", progress: 0.0);
    final newTotal = state.fetchingMetadata.isEmpty ? 1 : state.metadataFetchTotalCount + 1;
    emit(state.copyWith(fetchingMetadata: newFetching, metadataFetchTotalCount: newTotal));

    try {
      if (book.coverPath != null) {
        final coverFile = File(book.coverPath!);
        if (await coverFile.exists()) await coverFile.delete();
      }
      _enqueueEbooks([book.copyWith(hasMetadataLocally: false, coverPath: null)]);
    } catch (e) {
      final revertedFetching = Map<String, BookFetchStatus>.from(state.fetchingMetadata)..remove(book.file);
      final newTotal = revertedFetching.isEmpty ? 0 : state.metadataFetchTotalCount;
      emit(state.copyWith(fetchingMetadata: revertedFetching, error: 'Failed to force fetch: $e', metadataFetchTotalCount: newTotal));
    }
  }

  Future<Audiobook> ensureChaptersCalculated(Audiobook book) async {
    // If durations are already calculated, do nothing
    final needsCalculation = book.chapters.isEmpty || book.chapters.every((c) => c.duration == 0.0);
    if (!needsCalculation) {
      debugPrint('ensureChaptersCalculated: Audiobook chapters already calculated for ${book.path}');
      return book;
    }

    debugPrint('ensureChaptersCalculated: Starting duration/chapter calculation in isolate for ${book.path}');
    final result = await Isolate.run(() async {
      debugPrint('ensureChaptersCalculated isolate: scanning files for ${book.path}');
      double cumulativeStart = 0.0;
      final List<Chapter> calculatedChapters = [];
      
      for (int i = 0; i < book.files.length; i++) {
        final path = book.files[i];
        debugPrint('ensureChaptersCalculated isolate: analyzing file [$i/${book.files.length}]: $path');
        double fileDuration = 0.0;
        try {
          final meta = await AudiobookScanner.getAudioMetadata(File(path));
          fileDuration = meta?.durationInSeconds ?? 0.0;
        } catch (_) {}
        
        final parentDir = p.dirname(path);
        final grandparentDir = p.dirname(parentDir);
        String? partName;
        if (grandparentDir == book.path) {
          partName = p.basename(parentDir);
        }
        
        calculatedChapters.add(Chapter(
          index: i,
          start: cumulativeStart,
          end: cumulativeStart + fileDuration,
          duration: fileDuration,
          startFormatted: AudiobookScanner.formatDuration(cumulativeStart),
          endFormatted: AudiobookScanner.formatDuration(cumulativeStart + fileDuration),
          durationFormatted: AudiobookScanner.formatDuration(fileDuration),
          title: p.basenameWithoutExtension(path),
          displayTitle: partName != null
              ? '$partName - Chapter ${i + 1}'
              : 'Chapter ${i + 1}',
          part: partName,
        ));
        
        cumulativeStart += fileDuration;
      }

      final durationStr = AudiobookScanner.formatDuration(cumulativeStart);
      debugPrint('ensureChaptersCalculated isolate: completed. Total duration: $durationStr');
      return {
        'durationFormatted': durationStr,
        'chapters': calculatedChapters,
      };
    });

    final durationStr = result['durationFormatted'] as String;
    final calculatedChapters = result['chapters'] as List<Chapter>;
    debugPrint('ensureChaptersCalculated: isolate finished, updating state and database');

    final updatedBook = book.copyWith(
      durationFormatted: durationStr,
      chapters: calculatedChapters,
    );

    // Save/update in local database/state
    final currentBooks = List<Audiobook>.from(state.audiobooks);
    final index = currentBooks.indexWhere((b) => b.path == book.path);
    if (index != -1) {
      currentBooks[index] = updatedBook;
      emit(state.copyWith(audiobooks: currentBooks));
      await _storage.saveAudiobooks(currentBooks);
    }

    // Also update book.metadata.json if it exists
    try {
      final metaFile = AudiobookScanner.getBookMetadataFile(book.path);
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        json['durationFormatted'] = durationStr;
        json['chapters'] = calculatedChapters.map((c) => c.toJson()).toList();
        await metaFile.writeAsString(jsonEncode(json));
      }
    } catch (_) {}

    return updatedBook;
  }

  /// Replaces chapter structure after on-device detection review.
  Future<Audiobook> applyDetectedChapters(
    Audiobook book,
    List<Chapter> chapters,
  ) async {
    final durationStr = chapters.isEmpty
        ? book.durationFormatted
        : AudiobookScanner.formatDuration(chapters.last.end);

    final updatedBook = book.copyWith(
      chapters: chapters,
      totalChapters: chapters.length,
      durationFormatted: durationStr,
    );

    final currentBooks = List<Audiobook>.from(state.audiobooks);
    final index = currentBooks.indexWhere((b) => b.path == book.path);
    if (index != -1) {
      currentBooks[index] = updatedBook;
      emit(state.copyWith(audiobooks: currentBooks));
      await _storage.saveAudiobooks(currentBooks);
    }

    try {
      final metaFile = AudiobookScanner.getBookMetadataFile(book.path);
      Map<String, dynamic> json = {};
      if (await metaFile.exists()) {
        json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      }
      json['durationFormatted'] = durationStr;
      json['totalChapters'] = chapters.length;
      json['chapters'] = chapters.map((c) => c.toJson()).toList();
      await metaFile.writeAsString(jsonEncode(json));
    } catch (_) {}

    return updatedBook;
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

  void setActivePlaylist(int? playlistId) {
    emit(state.copyWith(activePlaylistId: playlistId, clearActivePlaylist: playlistId == null));
  }

  /// Orders books for series/universe playback:
  /// hierarchical readingOrderKey (saga → era → book) → sequence → year → title.
  ///
  /// When a universe mixes numbered standalones and sagas, books of a saga
  /// form a contiguous block under the saga's order token before the next item.
  static int compareLibraryOrder(Audiobook a, Audiobook b) {
    final keyA = a.readingOrderKey;
    final keyB = b.readingOrderKey;
    if (keyA.isNotEmpty || keyB.isNotEmpty) {
      final cmp = AudiobookScanner.compareReadingOrderKeys(keyA, keyB);
      if (cmp != 0) return cmp;
    }

    final seqA = double.tryParse(a.seriesSequence ?? '');
    final seqB = double.tryParse(b.seriesSequence ?? '');
    if (seqA != null && seqB != null) {
      final cmp = seqA.compareTo(seqB);
      if (cmp != 0) return cmp;
    } else if (seqA != null) {
      return -1;
    } else if (seqB != null) {
      return 1;
    }

    final yearA = int.tryParse(a.publishYear ?? '');
    final yearB = int.tryParse(b.publishYear ?? '');
    if (yearA != null && yearB != null) {
      final cmp = yearA.compareTo(yearB);
      if (cmp != 0) return cmp;
    } else if (yearA != null) {
      return -1;
    } else if (yearB != null) {
      return 1;
    }

    final seriesCmp = (a.series ?? '').compareTo(b.series ?? '');
    if (seriesCmp != 0) return seriesCmp;
    return a.title.compareTo(b.title);
  }

  Audiobook? _bookByPath(String path) {
    for (final b in state.audiobooks) {
      if (b.path == path) return b;
    }
    return null;
  }

  Audiobook? _nextInPlaylist(Audiobook currentBook) {
    final playlistId = state.activePlaylistId;
    if (playlistId == null) return null;

    Playlist? playlist;
    for (final p in state.playlists) {
      if (p.id == playlistId) {
        playlist = p;
        break;
      }
    }
    if (playlist == null) return null;

    final currentIndex = playlist.bookPaths.indexOf(currentBook.path);
    if (currentIndex == -1 || currentIndex >= playlist.bookPaths.length - 1) {
      return null;
    }
    return _bookByPath(playlist.bookPaths[currentIndex + 1]);
  }

  Audiobook? _nextInSeries(Audiobook currentBook) {
    final series = currentBook.series?.trim();
    if (series == null || series.isEmpty) return null;

    final seriesBooks = state.audiobooks.where((b) {
      if (b.series != series) return false;
      if (b.author != currentBook.author) return false;
      final u = currentBook.universe;
      if (u != null &&
          u.isNotEmpty &&
          b.universe != null &&
          b.universe!.isNotEmpty &&
          b.universe != u) {
        return false;
      }
      return true;
    }).toList()
      ..sort(compareLibraryOrder);

    final currentIndex =
        seriesBooks.indexWhere((b) => b.path == currentBook.path);
    if (currentIndex == -1 || currentIndex >= seriesBooks.length - 1) {
      return null;
    }
    return seriesBooks[currentIndex + 1];
  }

  Audiobook? _nextInUniverse(Audiobook currentBook) {
    final universe = currentBook.universe?.trim();
    if (universe == null || universe.isEmpty) return null;

    final universeBooks = state.audiobooks.where((b) {
      return b.author == currentBook.author && b.universe == universe;
    }).toList()
      ..sort(compareLibraryOrder);

    final currentIndex =
        universeBooks.indexWhere((b) => b.path == currentBook.path);
    if (currentIndex == -1 || currentIndex >= universeBooks.length - 1) {
      return null;
    }
    return universeBooks[currentIndex + 1];
  }

  /// Marks the book as read and resolves what to play next (if anything).
  /// Active playlist auto-advances; series/universe only proposes.
  Future<AudiobookCompletionResult> onAudiobookCompleted(
    Audiobook currentBook,
  ) async {
    await markAsRead(currentBook);

    final playlistNext = _nextInPlaylist(currentBook);
    if (playlistNext != null) {
      return AudiobookCompletionResult(
        nextBook: playlistNext,
        autoAdvance: true,
      );
    }

    final relatedNext =
        _nextInSeries(currentBook) ?? _nextInUniverse(currentBook);
    if (relatedNext != null) {
      return AudiobookCompletionResult(
        nextBook: relatedNext,
        autoAdvance: false,
      );
    }

    return const AudiobookCompletionResult();
  }
}

/// Result of finishing an audiobook: optional next book and whether to auto-play.
class AudiobookCompletionResult {
  final Audiobook? nextBook;

  /// When true (e.g. active playlist), advance without asking.
  final bool autoAdvance;

  const AudiobookCompletionResult({
    this.nextBook,
    this.autoAdvance = false,
  });
}
