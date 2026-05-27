import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/audiobook.dart';

const _keyScanPaths = 'audiobook_scan_paths';
const _keyAudiobooks = 'audiobook_library';

/// Persists scan paths and audiobook library.
class LibraryStorage {
  static Future<List<String>> getScanPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyScanPaths);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> saveScanPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScanPaths, jsonEncode(paths));
  }

  static Future<void> addScanPath(String path) async {
    final paths = await getScanPaths();
    if (!paths.contains(path)) {
      paths.add(path);
      await saveScanPaths(paths);
    }
  }

  static Future<void> removeScanPath(String path) async {
    final paths = await getScanPaths();
    paths.remove(path);
    await saveScanPaths(paths);
  }

  static Future<List<Audiobook>> getAudiobooks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyAudiobooks);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Audiobook.fromJson(
              e as Map<String, dynamic>,
              (e['path'] as String?) ?? ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAudiobooks(List<Audiobook> audiobooks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = audiobooks.map((a) => a.toJson()).toList();
    await prefs.setString(_keyAudiobooks, jsonEncode(list));
  }
}
