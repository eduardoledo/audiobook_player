import 'book_metadata.dart';
import 'models.dart';
import 'path_metadata.dart';

/// Known author / universe / series / narrator values from saved metadata.
class MetadataCatalog {
  final Set<String> authors = {};
  final Set<String> universes = {};
  final Set<String> seriesNames = {};
  final Set<String> narrators = {};
  final Set<String> titles = {};

  /// Grouped suggestions for smarter autocomplete.
  final Map<String, Set<String>> seriesByAuthor = {};
  final Map<String, Set<String>> universesByAuthor = {};
  final Map<String, Set<String>> narratorsByAuthor = {};
  final Map<String, Set<String>> titlesByAuthor = {};

  void addFromMetadata(BookMetadata meta) {
    final author = meta.author.trim();
    if (author.isNotEmpty && author.toLowerCase() != 'unknown') {
      authors.add(author);
    }

    final title = meta.title.trim();
    if (title.isNotEmpty && meta.entryType == 'book') {
      titles.add(title);
      if (author.isNotEmpty) {
        titlesByAuthor.putIfAbsent(author, () => {}).add(title);
      }
    }
    // Parent book titles referenced by parts are also useful for partOf.
    final partOf = meta.partOf?.trim();
    if (partOf != null && partOf.isNotEmpty) {
      titles.add(partOf);
      if (author.isNotEmpty) {
        titlesByAuthor.putIfAbsent(author, () => {}).add(partOf);
      }
    }

    final narrator = meta.narrator?.trim();
    if (narrator != null && narrator.isNotEmpty) {
      narrators.add(narrator);
      if (author.isNotEmpty) {
        narratorsByAuthor.putIfAbsent(author, () => {}).add(narrator);
      }
    }

    final universe = meta.universe?.trim();
    if (universe != null && universe.isNotEmpty) {
      universes.add(universe);
      if (author.isNotEmpty) {
        universesByAuthor.putIfAbsent(author, () => {}).add(universe);
      }
    }
    final series = meta.seriesName?.trim();
    if (series != null && series.isNotEmpty) {
      seriesNames.add(series);
      if (author.isNotEmpty) {
        seriesByAuthor.putIfAbsent(author, () => {}).add(series);
      }
    }
  }

  void addFromBook(ScannedBook book) {
    final existing = loadBookMetadata(book.path);
    if (existing != null) {
      addFromMetadata(existing);
      return;
    }
    final author = book.author.trim();
    if (author.isNotEmpty && author.toLowerCase() != 'unknown') {
      authors.add(author);
    }
    final title = book.pathMeta.bookTitle.trim();
    if (title.isNotEmpty && !looksLikePartFolder(title)) {
      titles.add(title);
      if (author.isNotEmpty) {
        titlesByAuthor.putIfAbsent(author, () => {}).add(title);
      }
    }
    final universe = book.universe?.trim();
    if (universe != null && universe.isNotEmpty) {
      universes.add(universe);
      if (author.isNotEmpty) {
        universesByAuthor.putIfAbsent(author, () => {}).add(universe);
      }
    }
    final series = book.series?.trim();
    if (series != null && series.isNotEmpty) {
      seriesNames.add(series);
      if (author.isNotEmpty) {
        seriesByAuthor.putIfAbsent(author, () => {}).add(series);
      }
    }
  }

  static MetadataCatalog fromBooks(Iterable<ScannedBook> books) {
    final catalog = MetadataCatalog();
    for (final book in books) {
      catalog.addFromBook(book);
    }
    return catalog;
  }

  List<String> suggestionsFor(
    String field, {
    String? author,
    String? prefix,
  }) {
    Iterable<String> source;
    switch (field) {
      case 'author':
        source = authors;
        break;
      case 'narrator':
        final byAuthor = author != null ? narratorsByAuthor[author] : null;
        source =
            (byAuthor != null && byAuthor.isNotEmpty) ? byAuthor : narrators;
        break;
      case 'universe':
        final byAuthor = author != null ? universesByAuthor[author] : null;
        source =
            (byAuthor != null && byAuthor.isNotEmpty) ? byAuthor : universes;
        break;
      case 'seriesName':
        final byAuthor = author != null ? seriesByAuthor[author] : null;
        source =
            (byAuthor != null && byAuthor.isNotEmpty) ? byAuthor : seriesNames;
        break;
      case 'partOf':
        final byAuthor = author != null ? titlesByAuthor[author] : null;
        source = (byAuthor != null && byAuthor.isNotEmpty) ? byAuthor : titles;
        break;
      default:
        return const [];
    }

    var list = source.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final p = prefix?.trim().toLowerCase();
    if (p != null && p.isNotEmpty) {
      list = list.where((v) => v.toLowerCase().contains(p)).toList();
    }
    return list;
  }
}
