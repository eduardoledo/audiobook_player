import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/audiobook.dart';
import '../models/bookmark.dart';
import '../models/playlist.dart';

/// Persists scan paths and audiobook library using SQLite.
class LibraryStorage {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'audiobook_library.db');
    
    _db = await openDatabase(
      path,
      version: 4,
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
      },
    );
    return _db!;
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
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('audiobooks');
    final List<Audiobook> books = [];
    
    for (var row in maps) {
      try {
        final path = row['path'] as String;
        final jsonStr = row['json_data'] as String;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        books.add(Audiobook.fromJson(map, path));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return books;
  }

  Future<void> saveAudiobooks(List<Audiobook> audiobooks) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('audiobooks');
      for (final a in audiobooks) {
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
  }

  Future<void> savePlaybackProgress(String bookPath, int chapterIndex, int positionMs) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    final maps = await db.query('bookmarks', where: 'book_path = ?', whereArgs: [bookPath], orderBy: 'position_ms ASC');
    return maps.map((e) => Bookmark(
      id: e['id'] as int,
      bookPath: e['book_path'] as String,
      positionMs: e['position_ms'] as int,
      label: e['label'] as String?,
    )).toList();
  }

  Future<void> addBookmark(String bookPath, int positionMs, String? label) async {
    final db = await database;
    await db.insert('bookmarks', {
      'book_path': bookPath,
      'position_ms': positionMs,
      'label': label,
    });
  }

  Future<void> removeBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
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
}
