import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/category_node.dart';

class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics;

  CrashlyticsService({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  Future<void> init() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
  }

  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }

  Future<void> updateContext({
    String? bookPath,
    int? categoryId,
    List<CategoryNode>? categories,
    bool? isPlaying,
    int? positionMs,
    String? viewMode,
    bool? isScanning,
  }) async {
    if (bookPath != null) {
      await setCustomKey('current_book_path', bookPath);
    }
    if (categories != null && categoryId != null) {
      final hierarchyPath = computeCategoryHierarchyPath(
        bookCategoryId: categoryId,
        allCategories: categories,
      );
      if (hierarchyPath.isNotEmpty) {
        await setCustomKey('category_hierarchy_path', hierarchyPath);
      }
    }
    if (isPlaying != null) {
      await setCustomKey('is_playing', isPlaying);
    }
    if (positionMs != null) {
      await setCustomKey('playback_position_ms', positionMs);
    }
    if (viewMode != null) {
      await setCustomKey('library_view_mode', viewMode);
    }
    if (isScanning != null) {
      await setCustomKey('is_scanning', isScanning);
    }
  }

  static String computeCategoryHierarchyPath({
    required int? bookCategoryId,
    required List<CategoryNode> allCategories,
  }) {
    if (bookCategoryId == null || allCategories.isEmpty) return '';

    final categoryMap = {for (final c in allCategories) c.id: c};
    final chain = <String>[];
    int? currentId = bookCategoryId;

    while (currentId != null && categoryMap.containsKey(currentId)) {
      final node = categoryMap[currentId]!;
      chain.add(node.name);
      currentId = node.parentId;
    }

    if (chain.isEmpty) return '';
    return chain.reversed.join(' > ');
  }
}
