import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/audiobook.dart';
import '../models/ebook.dart';
import '../models/bookmark.dart';
import '../models/playlist.dart';

/// Persists scan paths and audiobook library using SQLite.
class LibraryStorage {
  Database? _db;

  final Map<String, Database> _localDbs = {};

  Future<Database> _getLocalDatabase(String scanPath) async {
    if (_localDbs.containsKey(scanPath)) {
      return _localDbs[scanPath]!;
    }
    
    final metadataDir = Directory(p.join(scanPath, '_metadata'));
    if (!await metadataDir.exists()) {
      await metadataDir.create(recursive: true);
    }
    
    final dbPath = p.join(metadataDir.path, 'audiobook_library.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE audiobooks (
            path TEXT PRIMARY KEY,
            json_data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE ebooks (
            file TEXT PRIMARY KEY,
            json_data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playback_progress (
            path TEXT PRIMARY KEY,
            chapter_index INTEGER,
            position_ms INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_path TEXT,
            position_ms INTEGER,
            label TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE book_audio_settings (
            path TEXT PRIMARY KEY,
            eq_preset TEXT,
            loudness_enabled INTEGER,
            loudness_gain REAL,
            skip_silences INTEGER,
            pitch_stabilized INTEGER
          )
        ''');
      },
    );
    
    _localDbs[scanPath] = db;
    return db;
  }

  Future<String?> _getScanPathForBook(String bookPath) async {
    final paths = await getScanPaths();
    for (final scanPath in paths) {
      if (bookPath == scanPath || bookPath.startsWith('$scanPath${Platform.pathSeparator}')) {
        return scanPath;
      }
    }
    return null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'audiobook_library.db');
    
    _db = await openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_paths (
            path TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE audiobooks (
            path TEXT PRIMARY KEY,
            json_data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ebooks (
            file TEXT PRIMARY KEY,
            json_data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playback_progress (
            path TEXT PRIMARY KEY,
            chapter_index INTEGER,
            position_ms INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_books (
            playlist_id INTEGER,
            book_path TEXT,
            FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_path TEXT,
            position_ms INTEGER,
            label TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE book_audio_settings (
            path TEXT PRIMARY KEY,
            eq_preset TEXT,
            loudness_enabled INTEGER,
            loudness_gain REAL,
            skip_silences INTEGER,
            pitch_stabilized INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS authors (
            name TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sagas (
            name TEXT PRIMARY KEY
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE playback_progress (
              path TEXT PRIMARY KEY,
              chapter_index INTEGER,
              position_ms INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE playlists (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE playlist_books (
              playlist_id INTEGER,
              book_path TEXT,
              FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE bookmarks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_path TEXT,
              position_ms INTEGER,
              label TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE book_audio_settings (
              path TEXT PRIMARY KEY,
              eq_preset TEXT,
              loudness_enabled INTEGER,
              loudness_gain REAL,
              skip_silences INTEGER,
              pitch_stabilized INTEGER
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ebooks (
              file TEXT PRIMARY KEY,
              json_data TEXT
            )
          ''');
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS authors (
              name TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sagas (
              name TEXT PRIMARY KEY
            )
          ''');
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ebooks (
              file TEXT PRIMARY KEY,
              json_data TEXT
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<Set<String>> getAuthors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('authors');
    return maps.map((e) => e['name'] as String).toSet();
  }

  Future<void> saveAuthors(Set<String> authors) async {
    if (authors.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final author in authors) {
        await txn.insert(
          'authors',
          {'name': author},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<Set<String>> getSagas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sagas');
    return maps.map((e) => e['name'] as String).toSet();
  }

  Future<void> saveSagas(Set<String> sagas) async {
    if (sagas.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final saga in sagas) {
        await txn.insert(
          'sagas',
          {'name': saga},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<String>> getScanPaths() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('scan_paths');
    return maps.map((e) => e['path'] as String).toList();
  }

  Future<void> saveScanPaths(List<String> paths) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('scan_paths');
      for (final path in paths) {
        await txn.insert(
          'scan_paths', 
          {'path': path},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> addScanPath(String path) async {
    final db = await database;
    await db.insert(
      'scan_paths', 
      {'path': path}, 
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeScanPath(String path) async {
    final db = await database;
    await db.delete('scan_paths', where: 'path = ?', whereArgs: [path]);
  }

  Future<List<Audiobook>> getAudiobooks() async {
    final paths = await getScanPaths();
    final List<Audiobook> books = [];
    
    for (final scanPath in paths) {
      try {
        final db = await _getLocalDatabase(scanPath);
        final List<Map<String, dynamic>> maps = await db.query('audiobooks');
        
        for (var row in maps) {
          try {
            final path = row['path'] as String;
            final jsonStr = row['json_data'] as String;
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            books.add(Audiobook.fromJson(map, path));
          } catch (_) {}
        }
      } catch (e) {
        // Database might not exist yet or is corrupted
      }
    }
    return books;
  }

  Future<void> saveAudiobooks(List<Audiobook> audiobooks) async {
    // Group books by scan path
    final Map<String, List<Audiobook>> grouped = {};
    for (final a in audiobooks) {
      final scanPath = await _getScanPathForBook(a.path);
      if (scanPath != null) {
        grouped.putIfAbsent(scanPath, () => []).add(a);
      }
    }
    
    for (final scanPath in grouped.keys) {
      try {
        final db = await _getLocalDatabase(scanPath);
        await db.transaction((txn) async {
          await txn.delete('audiobooks');
          for (final a in grouped[scanPath]!) {
            await txn.insert(
              'audiobooks', 
              {
                'path': a.path,
                'json_data': jsonEncode(a.toJson()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      } catch (_) {}
    }
  }

  Future<List<Ebook>> getEbooks() async {
    final paths = await getScanPaths();
    final List<Ebook> ebooks = [];
    
    for (final scanPath in paths) {
      try {
        final db = await _getLocalDatabase(scanPath);
        final List<Map<String, dynamic>> maps = await db.query('ebooks');
        
        for (var row in maps) {
          try {
            final file = row['file'] as String;
            final jsonStr = row['json_data'] as String;
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            // Extract basePath from the file path
            final basePath = p.dirname(file); 
            ebooks.add(Ebook.fromJson(map, basePath));
          } catch (_) {}
        }
      } catch (e) {
        // Database might not exist yet or is corrupted
      }
    }
    return ebooks;
  }

  Future<void> saveEbooks(List<Ebook> ebooks) async {
    // Group books by scan path
    final Map<String, List<Ebook>> grouped = {};
    for (final e in ebooks) {
      final scanPath = await _getScanPathForBook(e.file);
      if (scanPath != null) {
        grouped.putIfAbsent(scanPath, () => []).add(e);
      }
    }
    
    for (final scanPath in grouped.keys) {
      try {
        final db = await _getLocalDatabase(scanPath);
        await db.transaction((txn) async {
          await txn.delete('ebooks');
          for (final e in grouped[scanPath]!) {
            await txn.insert(
              'ebooks', 
              {
                'file': e.file,
                'json_data': jsonEncode(e.toJson()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      } catch (_) {}
    }
  }

  Future<void> savePlaybackProgress(String bookPath, int chapterIndex, int positionMs) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return;
    final db = await _getLocalDatabase(scanPath);
    await db.insert(
      'playback_progress',
      {
        'path': bookPath,
        'chapter_index': chapterIndex,
        'position_ms': positionMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>?> getPlaybackProgress(String bookPath) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return null;
    final db = await _getLocalDatabase(scanPath);
    final maps = await db.query('playback_progress', where: 'path = ?', whereArgs: [bookPath]);
    if (maps.isNotEmpty) {
      return {
        'chapterIndex': maps.first['chapter_index'] as int,
        'positionMs': maps.first['position_ms'] as int,
      };
    }
    return null;
  }

  // --- Settings ---
  
  Future<Map<String, List<String>>> getSeriesMappingRules() async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: ['series_mapping_rules']);
    if (maps.isNotEmpty) {
      final jsonStr = maps.first['value'] as String;
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
      } catch (_) {}
    }
    return {};
  }

  Future<void> saveSeriesMappingRules(Map<String, List<String>> rules) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'series_mapping_rules',
      'value': jsonEncode(rules),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<String>> getGlobalPatterns() async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: ['global_patterns']);
    if (maps.isNotEmpty) {
      final jsonStr = maps.first['value'] as String;
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    // Default patterns if none are set
    return [
      r'^(?<year>\d{4})\s*-\s*(?<title>[^(]+?)\s*\([^)]*?(?:read by|narrated by)\s*(?<narrator>[^)]+).*$',
      r'\[(?<seriesCode>[A-Za-z]+)\s*(?<seriesSequence>\d+)\]\s*(?<title>.*)',
      r'^(?<author>[^/]+)/(?<series>[^/]+)/(?<seriesSequence>\d+)\s*-\s*(?<title>.*)$',
      r'^(?<author>[^/]+)/(?<title>.*)$',
    ];
  }

  Future<void> saveGlobalPatterns(List<String> patterns) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'global_patterns',
      'value': jsonEncode(patterns),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getSagaCodes() async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: ['saga_codes']);
    if (maps.isNotEmpty) {
      final jsonStr = maps.first['value'] as String;
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (_) {}
    }
    return {};
  }

  Future<void> saveSagaCodes(Map<String, String> codes) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'saga_codes',
      'value': jsonEncode(codes),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Bookmarks ---
  
  Future<List<Bookmark>> getBookmarks(String bookPath) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return [];
    final db = await _getLocalDatabase(scanPath);
    final maps = await db.query('bookmarks', where: 'book_path = ?', whereArgs: [bookPath], orderBy: 'position_ms ASC');
    return maps.map((e) => Bookmark(
      id: e['id'] as int,
      bookPath: e['book_path'] as String,
      positionMs: e['position_ms'] as int,
      label: e['label'] as String?,
    )).toList();
  }

  Future<void> addBookmark(String bookPath, int positionMs, String? label) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return;
    final db = await _getLocalDatabase(scanPath);
    await db.insert('bookmarks', {
      'book_path': bookPath,
      'position_ms': positionMs,
      'label': label,
    });
  }

  Future<void> removeBookmark(int id) async {
    // Note: since we don't know the book path from just the id, we must search across all dbs.
    final paths = await getScanPaths();
    for (final scanPath in paths) {
      try {
        final db = await _getLocalDatabase(scanPath);
        final count = await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
        if (count > 0) return;
      } catch (_) {}
    }
  }

  // --- Playlists ---

  Future<List<Playlist>> getPlaylists() async {
    final db = await database;
    final maps = await db.query('playlists');
    final List<Playlist> playlists = [];
    for (var row in maps) {
      final id = row['id'] as int;
      final name = row['name'] as String;
      
      final booksQuery = await db.query('playlist_books', where: 'playlist_id = ?', whereArgs: [id]);
      final bookPaths = booksQuery.map((e) => e['book_path'] as String).toList();
      
      playlists.add(Playlist(id: id, name: name, bookPaths: bookPaths));
    }
    return playlists;
  }

  Future<Playlist> createPlaylist(String name) async {
    final db = await database;
    final id = await db.insert('playlists', {'name': name});
    return Playlist(id: id, name: name);
  }

  Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_books', where: 'playlist_id = ?', whereArgs: [id]);
  }

  Future<void> addBookToPlaylist(int playlistId, String bookPath) async {
    final db = await database;
    // Prevent duplicates
    final existing = await db.query('playlist_books', where: 'playlist_id = ? AND book_path = ?', whereArgs: [playlistId, bookPath]);
    if (existing.isEmpty) {
      await db.insert('playlist_books', {'playlist_id': playlistId, 'book_path': bookPath});
    }
  }

  Future<void> removeBookFromPlaylist(int playlistId, String bookPath) async {
    final db = await database;
    await db.delete('playlist_books', where: 'playlist_id = ? AND book_path = ?', whereArgs: [playlistId, bookPath]);
  }

  // --- Book Audio Settings ---

  Future<Map<String, dynamic>?> getBookAudioSettings(String bookPath) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return null;
    final db = await _getLocalDatabase(scanPath);
    final List<Map<String, dynamic>> maps = await db.query(
      'book_audio_settings',
      where: 'path = ?',
      whereArgs: [bookPath],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> saveBookAudioSettings({
    required String bookPath,
    required String eqPreset,
    required bool loudnessEnabled,
    required double loudnessGain,
    required bool skipSilences,
    required bool pitchStabilized,
  }) async {
    final scanPath = await _getScanPathForBook(bookPath);
    if (scanPath == null) return;
    final db = await _getLocalDatabase(scanPath);
    await db.insert(
      'book_audio_settings',
      {
        'path': bookPath,
        'eq_preset': eqPreset,
        'loudness_enabled': loudnessEnabled ? 1 : 0,
        'loudness_gain': loudnessGain,
        'skip_silences': skipSilences ? 1 : 0,
        'pitch_stabilized': pitchStabilized ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getLastPlayedBook() async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: ['last_played_book_path']);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> saveLastPlayedBook(String path) async {
    final db = await database;
    await db.insert(
      'settings',
      {
        'key': 'last_played_book_path',
        'value': path,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
