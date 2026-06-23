class Bookmark {
  final int? id;
  final String bookPath;
  final int positionMs;
  final String? label;

  const Bookmark({
    this.id,
    required this.bookPath,
    required this.positionMs,
    this.label,
  });
  
  String get positionFormatted {
    final d = Duration(milliseconds: positionMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
