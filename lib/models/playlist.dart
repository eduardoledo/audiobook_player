class Playlist {
  final int? id;
  final String name;
  final List<String> bookPaths;

  const Playlist({
    this.id,
    required this.name,
    this.bookPaths = const [],
  });

  Playlist copyWith({
    int? id,
    String? name,
    List<String>? bookPaths,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      bookPaths: bookPaths ?? this.bookPaths,
    );
  }
}
