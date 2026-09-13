import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'book_metadata.dart';
import 'catalog.dart';
import 'chapters_from_files.dart';
import 'interactive.dart';
import 'models.dart';
import 'online_fetcher.dart';
import 'saved_structure.dart';
import 'scanner.dart';
import 'structure_pipeline.dart';

ArgParser _chaptersFlag(ArgParser parser) => parser
  ..addFlag(
    'chapters',
    negatable: false,
    help: 'Detect chapters from audio filenames (first strategy)',
  );

Future<void> runMetadataCli(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage')
    // Also accepted before the subcommand: `metadata_cli --chapters scan …`
    ..addFlag(
      'chapters',
      negatable: false,
      help: 'Detect chapters from audio filenames (first strategy)',
    )
    ..addCommand(
      'scan',
      _chaptersFlag(
        ArgParser()..addFlag('help', abbr: 'h', negatable: false),
      ),
    )
    ..addCommand(
      'write',
      _chaptersFlag(
        ArgParser()
          ..addFlag('help', abbr: 'h', negatable: false)
          ..addFlag(
            'only-missing',
            defaultsTo: true,
            help: 'Only books without book.metadata.json (default)',
          )
          ..addFlag(
            'force',
            abbr: 'f',
            negatable: false,
            help: 'Reprocess all books (merge into existing metadata)',
          )
          ..addFlag(
            'reprocess',
            abbr: 'a',
            negatable: false,
            help: 'Same as --force: reprocess all books',
          )
          ..addFlag(
            'online',
            negatable: false,
            help: 'Enrich from iTunes / Google Books / OpenLibrary',
          )
          ..addFlag(
            'edit',
            negatable: false,
            help: 'Interactive confirm/edit per book',
          )
          ..addFlag(
            'yes',
            abbr: 'y',
            negatable: false,
            help: 'Non-interactive batch mode',
          )
          ..addFlag(
            'duration',
            defaultsTo: true,
            help: 'Estimate durationFormatted from audio files',
          ),
      ),
    )
    ..addCommand(
      'reprocess',
      _chaptersFlag(
        ArgParser()
          ..addFlag('help', abbr: 'h', negatable: false)
          ..addFlag(
            'online',
            negatable: false,
            help: 'Enrich from iTunes / Google Books / OpenLibrary',
          )
          ..addFlag(
            'edit',
            negatable: false,
            help: 'Interactive confirm/edit per book',
          )
          ..addFlag(
            'yes',
            abbr: 'y',
            negatable: false,
            help: 'Non-interactive batch mode',
          )
          ..addFlag(
            'duration',
            defaultsTo: true,
            help: 'Estimate durationFormatted from audio files',
          ),
      ),
    )
    ..addCommand(
      'edit',
      _chaptersFlag(
        ArgParser()
          ..addFlag('help', abbr: 'h', negatable: false)
          ..addFlag(
            'online',
            negatable: false,
            help: 'Enrich from online APIs before editing',
          )
          ..addFlag(
            'duration',
            defaultsTo: true,
            help: 'Estimate durationFormatted from audio files',
          ),
      ),
    )
    ..addCommand(
      'clear',
      ArgParser()
        ..addFlag('help', abbr: 'h', negatable: false)
        ..addFlag(
          'yes',
          abbr: 'y',
          negatable: false,
          help: 'Actually delete files (without this, dry-run only)',
        )
        ..addFlag(
          'covers',
          negatable: false,
          help: 'Also delete cover.jpg files',
        ),
    )
    ..addCommand(
      'structure',
      ArgParser()
        ..addFlag('help', abbr: 'h', negatable: false)
        ..addOption(
          'epub',
          help: 'EPUB path (default: sole .epub in book dir)',
        )
        ..addOption(
          'audio',
          help: 'Audio file (default: first audio in book dir)',
        )
        ..addFlag(
          'split',
          negatable: false,
          help: 'Split multi-chapter audio into per-chapter files',
        )
        ..addOption(
          'originals-dir',
          defaultsTo: 'originals',
          help: 'Folder under the book for archived originals',
        )
        ..addFlag(
          'dry-run',
          negatable: false,
          help: 'Parse/match/locate plan only; do not write or split',
        )
        ..addFlag(
          'yes',
          abbr: 'y',
          negatable: false,
          help: 'Non-interactive; with --split, perform split + metadata',
        )
        ..addFlag(
          'all-chapters',
          abbr: 'A',
          negatable: false,
          help: 'List every EPUB, embedded, and located chapter',
        )
        ..addFlag(
          'fast',
          defaultsTo: true,
          help:
              'Fast locate (default): skip full silence scan, coarse→fine ASR',
        )
        ..addFlag(
          'force-locate',
          negatable: false,
          help:
              'Ignore saved chapter times in book.metadata.json and re-locate',
        )
        ..addFlag(
          'fill-missing',
          defaultsTo: true,
          help:
              'If already split, locate missing EPUB chapters inside the '
              'previous chapter file and re-split it',
        ),
    );

  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (results['help'] == true || results.command == null) {
    _printUsage(parser);
    return;
  }

  final command = results.command!;
  final chaptersFromRoot = results['chapters'] as bool;
  switch (command.name) {
    case 'scan':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln('Usage: metadata_cli scan <root> [--chapters]');
        return;
      }
      await _cmdScan(
        command.rest.first,
        detectChapters:
            chaptersFromRoot || (command['chapters'] as bool),
      );
      break;
    case 'write':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln(
          'Usage: metadata_cli write <root> [--reprocess|--force] [--online] '
          '[--chapters] [--edit|--yes]',
        );
        return;
      }
      await _cmdWrite(
        root: command.rest.first,
        force: (command['force'] as bool) || (command['reprocess'] as bool),
        online: command['online'] as bool,
        edit: command['edit'] as bool,
        yes: command['yes'] as bool,
        estimateDuration: command['duration'] as bool,
        detectChapters:
            chaptersFromRoot || (command['chapters'] as bool),
      );
      break;
    case 'reprocess':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln(
          'Usage: metadata_cli reprocess <root> [--online] [--chapters] '
          '[--edit|--yes]',
        );
        return;
      }
      await _cmdWrite(
        root: command.rest.first,
        force: true,
        online: command['online'] as bool,
        edit: command['edit'] as bool,
        yes: command['yes'] as bool,
        estimateDuration: command['duration'] as bool,
        detectChapters:
            chaptersFromRoot || (command['chapters'] as bool),
      );
      break;
    case 'edit':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln(
          'Usage: metadata_cli edit <bookPath> [--online] [--chapters]',
        );
        return;
      }
      await _cmdEdit(
        bookPath: command.rest.first,
        online: command['online'] as bool,
        estimateDuration: command['duration'] as bool,
        detectChapters:
            chaptersFromRoot || (command['chapters'] as bool),
      );
      break;
    case 'clear':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln(
          'Usage: metadata_cli clear <root> [--yes] [--covers]',
        );
        return;
      }
      await _cmdClear(
        root: command.rest.first,
        yes: command['yes'] as bool,
        includeCovers: command['covers'] as bool,
      );
      break;
    case 'structure':
      if (command['help'] == true || command.rest.isEmpty) {
        stdout.writeln(
          'Usage: metadata_cli structure <bookPath> [--epub path] [--audio path] '
          '[--split] [--dry-run] [--yes] [--all-chapters] [--no-fast] '
          '[--force-locate] [--no-fill-missing] [--originals-dir originals]',
        );
        return;
      }
      await _cmdStructure(
        bookPath: command.rest.first,
        epub: command['epub'] as String?,
        audio: command['audio'] as String?,
        doSplit: command['split'] as bool,
        dryRun: command['dry-run'] as bool,
        yes: command['yes'] as bool,
        originalsDir: command['originals-dir'] as String,
        showAllChapters: command['all-chapters'] as bool,
        fast: command['fast'] as bool,
        forceLocate: command['force-locate'] as bool,
        fillMissing: command['fill-missing'] as bool,
      );
      break;
    default:
      _printUsage(parser);
      exitCode = 64;
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('''
metadata_cli — scan and create/update book.metadata.json

Commands:
  scan <root> [--chapters]    List detected audiobooks (optional chapter preview)
  write <root> [options]      Create/update metadata for books under root
  reprocess <root> [options]  Reprocess ALL books (same as write --reprocess)
  edit <bookPath> [options]   Interactively edit one book
  clear <root> [options]      Delete metadata sidecars under root
  structure <bookPath>        EPUB structure → audio chapters → optional split

Write / reprocess options:
  --only-missing (default)    Skip books that already have metadata
  --reprocess / -a / --force  Reprocess all books (merge into existing JSON)
  --online                    Fill missing fields via online APIs + cover.jpg
  --chapters                  Detect chapters from audio filenames
  --edit                      Interactive confirm/edit per book
  --yes / -y                  Batch mode without prompts
  --no-duration               Skip audio duration estimation

Structure options:
  --epub <path>               EPUB with TOC (default: .epub in book dir)
  --audio <file>              Audio to align/split (default: first audio)
  --split                     Split multi-chapter audio into chapter files
  --originals-dir <name>      Archive folder under book (default: originals)
  --dry-run                   Plan only (no write/split)
  --yes / -y                  Apply metadata; with --split, perform split
  --all-chapters / -A         List every detected chapter (EPUB/embedded/cuts)
  --fast / --no-fast          Fast locate (default on); --no-fast = thorough
  --force-locate              Ignore saved JSON times and re-locate
  --fill-missing / --no-fill-missing
                              If already split, hunt missing EPUB chapters
                              inside the previous chapter file (default on)

  If book.metadata.json already has chapter start/end times and the audio is
  still a single file, --split uses those times (no ASR). EPUB is optional then
  (used only to enrich part labels in filenames). If the saved timeline is
  incomplete vs the EPUB, locate resumes from the next missing chapter.

  If the book is already split into chapter files and the EPUB lists chapters
  that have no file, --fill-missing searches each gap inside the previous
  chapter's file and re-splits that file when found.

Clear options:
  (default)                   Dry-run: list files that would be deleted
  --yes / -y                  Actually delete the files
  --covers                    Also delete cover.jpg

Examples:
  metadata_cli scan /path/to/library
  metadata_cli scan /path/to/library --chapters
  metadata_cli write /path/to/library --yes
  metadata_cli write /path/to/library --yes --chapters
  metadata_cli reprocess /path/to/library --yes
  metadata_cli reprocess /path/to/library --online --yes --chapters
  metadata_cli write /path/to/library --reprocess --edit --online
  metadata_cli edit /path/to/library/Author/Saga/Book --online --chapters
  metadata_cli clear /path/to/library
  metadata_cli clear /path/to/library --yes
  metadata_cli clear /path/to/library --yes --covers
  metadata_cli structure /path/to/book --epub book.epub --dry-run
  metadata_cli structure /path/to/book --epub book.epub --dry-run --all-chapters
  metadata_cli structure /path/to/book --epub book.epub --split --yes
  metadata_cli structure /path/to/book --split --yes
  metadata_cli structure /path/to/book --split --yes --dry-run
  metadata_cli structure /path/to/book --fill-missing --yes
''');
}

Future<void> _cmdScan(
  String root, {
  required bool detectChapters,
}) async {
  final books = await scanLibrary(root);
  stdout.writeln('Found ${books.length} audiobook(s) under $root\n');
  for (final book in books) {
    final flag = book.hasMetadataFile ? 'OK ' : 'NEW';
    final series = book.series ?? '-';
    final universe = book.universe ?? '-';
    stdout.writeln(
      '[$flag] ${book.path}\n'
      '       ${book.author} / $universe / $series / ${book.pathMeta.bookTitle}'
      '${book.pathMeta.publishYear != null ? " (${book.pathMeta.publishYear})" : ""}'
      ' (${book.audioFiles.length} audio file(s))',
    );
    if (detectChapters && book.audioFiles.isNotEmpty) {
      final chapters = await detectChaptersFromFileNames(
        audioFiles: book.audioFiles,
        bookPath: book.path,
        includeDurations: false,
      );
      final relation = relateChaptersToParts(
        chapters: chapters,
        audioFiles: book.audioFiles,
        bookPath: book.path,
      );
      final finalized = relation.chapters;
      final parts = relation.parts;
      final preview = finalized.length > 6 ? 4 : finalized.length;
      stdout.writeln('       chapters (from filenames): ${finalized.length}');
      for (var i = 0; i < preview; i++) {
        final c = finalized[i];
        final part = c['part'];
        final label = part != null
            ? '$part • ${c['displayTitle']}'
            : '${c['displayTitle']}';
        stdout.writeln('         - $label');
      }
      if (finalized.length > preview) {
        stdout.writeln('         … +${finalized.length - preview} more');
      }
      if (parts.isNotEmpty) {
        stdout.writeln(
          '       parts: ${parts.map((p) => p.name).join(', ')}',
        );
      }
      if (!relation.isConsistent) {
        if (relation.chaptersMissingPart.isNotEmpty) {
          stdout.writeln(
            '       ! chapters missing part: '
            '${relation.chaptersMissingPart.join(', ')}',
          );
        }
        if (relation.orphanChapterParts.isNotEmpty) {
          stdout.writeln(
            '       ! orphan chapter.part: '
            '${relation.orphanChapterParts.join(', ')}',
          );
        }
        if (relation.partsWithoutChapters.isNotEmpty) {
          stdout.writeln(
            '       ! parts without chapters: '
            '${relation.partsWithoutChapters.join(', ')}',
          );
        }
      }
    }
  }
  final missing = books.where((b) => !b.hasMetadataFile).length;
  stdout.writeln(
    '\n$missing without metadata, ${books.length - missing} with metadata',
  );
}

Future<void> _cmdClear({
  required String root,
  required bool yes,
  required bool includeCovers,
}) async {
  List<File> files;
  try {
    files = await findLibraryMetadataFiles(
      root,
      includeCovers: includeCovers,
    );
  } on ArgumentError catch (e) {
    stderr.writeln(e.message);
    exitCode = 66;
    return;
  }

  if (files.isEmpty) {
    stdout.writeln('No metadata files found under $root');
    return;
  }

  final byName = <String, int>{};
  for (final f in files) {
    final name = p.basename(f.path);
    byName[name] = (byName[name] ?? 0) + 1;
  }

  stdout.writeln(
    yes
        ? 'Deleting ${files.length} metadata file(s) under $root'
        : 'Dry-run: ${files.length} metadata file(s) would be deleted under $root',
  );
  for (final entry in byName.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    stdout.writeln('  ${entry.value}× ${entry.key}');
  }

  if (!yes) {
    stdout.writeln(
      '\nRe-run with --yes to delete'
      '${includeCovers ? '' : ' (add --covers to include cover.jpg)'}.',
    );
    return;
  }

  final deleted = await clearLibraryMetadata(
    root,
    includeCovers: includeCovers,
  );
  stdout.writeln('\nDeleted ${deleted.length} file(s).');
}

Future<void> _cmdWrite({
  required String root,
  required bool force,
  required bool online,
  required bool edit,
  required bool yes,
  required bool estimateDuration,
  required bool detectChapters,
}) async {
  if (edit && yes) {
    stderr.writeln('Use either --edit or --yes, not both.');
    exitCode = 64;
    return;
  }
  if (!edit && !yes) {
    stdout.writeln(
      'Batch mode requires --yes (or use --edit for interactive).',
    );
    exitCode = 64;
    return;
  }

  final books = await scanLibrary(root);
  final catalog = MetadataCatalog.fromBooks(books);
  final targets = force
      ? books
      : books.where((b) => !b.hasMetadataFile).toList();

  stdout.writeln(
    'Processing ${targets.length}/${books.length} book(s)'
    '${force ? " (reprocess all)" : " (only missing)"}'
    '${online ? " + online" : ""}'
    '${detectChapters ? " + chapters" : ""}'
    '${edit ? " [interactive]" : ""}',
  );
  if (edit) {
    stdout.writeln(
      'Catalog: ${catalog.authors.length} authors, '
      '${catalog.universes.length} universes, '
      '${catalog.seriesNames.length} series, '
      '${catalog.narrators.length} narrators',
    );
  }

  var written = 0;
  var skipped = 0;
  var partsMerged = 0;

  for (var i = 0; i < targets.length; i++) {
    final book = targets[i];
    stdout.writeln('\n(${i + 1}/${targets.length}) ${book.path}');

    try {
      final result = await _processBook(
        book: book,
        online: online,
        interactive: edit,
        estimateDuration: estimateDuration,
        detectChapters: detectChapters,
        forceChapters: force && detectChapters,
        catalog: catalog,
        libraryBooks: books,
      );
      if (result == null) {
        skipped++;
        stdout.writeln('  → skipped');
      } else if (result.isPartMerge) {
        partsMerged++;
        stdout.writeln('  → merged part into ${result.savedPath}');
      } else {
        written++;
        stdout.writeln('  → saved book.metadata.json');
      }
    } catch (e) {
      if (isQuitException(e)) {
        stdout.writeln('Quit.');
        break;
      }
      stderr.writeln('  → error: $e');
    }

    if (online && i < targets.length - 1) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  stdout.writeln(
    '\nDone. books=$written partsMerged=$partsMerged skipped=$skipped',
  );
}

Future<void> _cmdEdit({
  required String bookPath,
  required bool online,
  required bool estimateDuration,
  required bool detectChapters,
}) async {
  final path = p.normalize(bookPath);
  if (!await Directory(path).exists()) {
    stderr.writeln('Book directory not found: $path');
    exitCode = 66;
    return;
  }

  // Walk up a few parents and keep the largest library that still contains
  // this book (for autocomplete from sibling metadata).
  List<ScannedBook> libraryBooks = [];
  ScannedBook? book;
  var probe = Directory(path);
  for (var level = 0; level < 5; level++) {
    try {
      final found = await scanLibrary(probe.path);
      ScannedBook? match;
      for (final b in found) {
        if (p.equals(b.path, path)) {
          match = b;
          break;
        }
      }
      if (match != null && found.length >= libraryBooks.length) {
        libraryBooks = found;
        book = match;
      }
    } catch (_) {}

    final parent = probe.parent;
    if (parent.path == probe.path) break;
    probe = parent;
  }

  if (book == null) {
    stderr.writeln('No audiobook detected at $path');
    exitCode = 66;
    return;
  }

  final catalog = MetadataCatalog.fromBooks(libraryBooks);
  stdout.writeln(
    'Catalog: ${catalog.authors.length} authors, '
    '${catalog.universes.length} universes, '
    '${catalog.seriesNames.length} series, '
    '${catalog.narrators.length} narrators',
  );

  try {
    final result = await _processBook(
      book: book,
      online: online,
      interactive: true,
      estimateDuration: estimateDuration,
      detectChapters: detectChapters,
      forceChapters: detectChapters,
      catalog: catalog,
      libraryBooks: libraryBooks,
    );
    if (result == null) {
      stdout.writeln('Skipped.');
    } else if (result.isPartMerge) {
      stdout.writeln('Part merged into ${result.savedPath}');
    } else {
      stdout.writeln('Saved.');
    }
  } catch (e) {
    if (isQuitException(e)) {
      stdout.writeln('Quit.');
      return;
    }
    rethrow;
  }
}

class _SaveResult {
  final String savedPath;
  final bool isPartMerge;

  const _SaveResult(this.savedPath, {this.isPartMerge = false});
}

Future<_SaveResult?> _processBook({
  required ScannedBook book,
  required bool online,
  required bool interactive,
  required bool estimateDuration,
  required bool detectChapters,
  required bool forceChapters,
  required List<ScannedBook> libraryBooks,
  MetadataCatalog? catalog,
}) async {
  final existing = loadBookMetadata(book.path);
  var meta = buildFromScan(book, existing: existing);

  if (estimateDuration && meta.durationFormatted == '00:00:00.000') {
    stdout.writeln('  Estimating duration...');
    final duration = await estimateDurationFormatted(book.audioFiles);
    if (duration != '00:00:00.000') {
      meta.durationFormatted = duration;
    }
  }

  if (detectChapters && !meta.isPart && book.audioFiles.isNotEmpty) {
    final shouldFill = forceChapters || chaptersNeedDetection(meta.chapters);
    if (shouldFill) {
      stdout.writeln('  Detecting chapters from filenames...');
      final chapters = await detectChaptersFromFileNames(
        audioFiles: book.audioFiles,
        bookPath: book.path,
        includeDurations: estimateDuration,
      );
      if (chapters.isNotEmpty) {
        // Always rebuild parts together with chapters so chapter.part and
        // parts[] stay related when structural parts exist.
        final relation = relateChaptersToParts(
          chapters: chapters,
          audioFiles: book.audioFiles,
          bookPath: book.path,
        );
        meta.chapters = relation.chapters;
        meta.parts = List<BookPart>.from(relation.parts);
        if (relation.parts.isNotEmpty) {
          stdout.writeln('  → ${relation.parts.length} part(s) from filenames');
        }
        // Keep book duration in sync when we measured per-file lengths.
        if (estimateDuration) {
          final last = meta.chapters.last;
          final end = last['endFormatted']?.toString();
          if (end != null &&
              end.isNotEmpty &&
              end != '00:00:00.000' &&
              (meta.durationFormatted == '00:00:00.000' || forceChapters)) {
            meta.durationFormatted = end;
          }
        }
        stdout.writeln('  → ${meta.chapters.length} chapter(s)');
        if (!relation.isConsistent) {
          stderr.writeln(
            '  ! chapter/part mismatch: '
            'missingPart=${relation.chaptersMissingPart} '
            'orphan=${relation.orphanChapterParts} '
            'emptyParts=${relation.partsWithoutChapters}',
          );
        }
      }
    }
  }

  if (online && !meta.isPart) {
    stdout.writeln('  Fetching online metadata...');
    final enrichment = await fetchOnlineMetadata(
      title: meta.title,
      author: meta.author,
      onStatus: (s) => stdout.writeln('  $s'),
    );
    meta = applyOnlineEnrichment(meta, enrichment);
    await downloadCoverIfMissing(
      bookPath: book.path,
      coverUrl: enrichment.coverUrl,
      onStatus: (s) => stdout.writeln('  $s'),
    );
  }

  if (interactive) {
    final edited = await interactiveEdit(
      meta,
      path: book.path,
      catalog: catalog,
    );
    if (edited == null) return null;
    meta = edited;
  }

  if (meta.isPart) {
    if ((meta.partOf == null || meta.partOf!.trim().isEmpty) && interactive) {
      stdout.writeln(
        'Esta entrada es una parte. Indicá el título del libro padre (partOf).',
      );
      final value = await _readPartOf(meta, catalog);
      if (value == null || value.trim().isEmpty) {
        stderr.writeln('partOf es requerido para fusionar la parte.');
        return null;
      }
      meta.setClearable('partOf', value);
    }
    final parentPath = await savePartIntoParentBook(
      partBook: book,
      partMeta: meta,
      libraryBooks: libraryBooks,
    );
    final parentMeta = loadBookMetadata(parentPath);
    if (parentMeta != null) catalog?.addFromMetadata(parentMeta);
    return _SaveResult(parentPath, isPartMerge: true);
  }

  meta.entryType = 'book';
  await saveBookMetadata(book.path, meta);
  catalog?.addFromMetadata(meta);
  return _SaveResult(book.path);
}

Future<String?> _readPartOf(
  BookMetadata meta,
  MetadataCatalog? catalog,
) async {
  stdout.writeln('Current partOf: ${meta.partOf ?? "(vacío)"}');
  if (catalog != null) {
    final suggestions = catalog.suggestionsFor(
      'partOf',
      author: meta.author.isNotEmpty ? meta.author : null,
    );
    if (suggestions.isNotEmpty) {
      final limit = suggestions.length > 15 ? 15 : suggestions.length;
      for (var i = 0; i < limit; i++) {
        stdout.writeln('  ${i + 1}) ${suggestions[i]}');
      }
    }
  }
  stdout.write('partOf> ');
  final input = stdin.readLineSync()?.trim() ?? '';
  if (input.isEmpty) return meta.partOf;
  final asNumber = int.tryParse(input);
  if (catalog != null && asNumber != null) {
    final suggestions = catalog.suggestionsFor(
      'partOf',
      author: meta.author.isNotEmpty ? meta.author : null,
    );
    if (asNumber >= 1 && asNumber <= suggestions.length) {
      return suggestions[asNumber - 1];
    }
  }
  return input;
}

Future<void> _cmdStructure({
  required String bookPath,
  required String? epub,
  required String? audio,
  required bool doSplit,
  required bool dryRun,
  required bool yes,
  required String originalsDir,
  required bool showAllChapters,
  required bool fast,
  required bool forceLocate,
  required bool fillMissing,
}) async {
  final book = p.normalize(bookPath);
  if (!Directory(book).existsSync()) {
    stderr.writeln('Book path not found: $book');
    exitCode = 66;
    return;
  }
  final discovered = discoverBookMedia(book);
  final epubPath = epub ?? discovered.epub;
  final audioPath = audio ?? discovered.audio;
  final wantsSplit = doSplit || (yes && !dryRun);
  final existingMeta = loadBookMetadata(book);
  final alreadySplit = isBookAudioAlreadySplit(book);
  final canSplitFromSaved = wantsSplit &&
      !forceLocate &&
      hasUsableSavedTimeline(existingMeta);
  final canFillMissing = alreadySplit &&
      fillMissing &&
      epubPath != null &&
      File(epubPath).existsSync();

  if (!canSplitFromSaved &&
      !canFillMissing &&
      (epubPath == null || !File(epubPath).existsSync())) {
    stderr.writeln(
      'EPUB required to locate chapters. Pass --epub or place a .epub in the '
      'book folder (or save chapter times in book.metadata.json and use --split).',
    );
    exitCode = 64;
    return;
  }
  if (!alreadySplit && (audioPath == null || !File(audioPath).existsSync())) {
    stderr.writeln(
      'Audio required. Pass --audio or place an audio file in the book folder.',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = await runStructurePipeline(
      StructurePipelineOptions(
        bookPath: book,
        epubPath: epubPath != null && File(epubPath).existsSync()
            ? p.normalize(epubPath)
            : null,
        audioPath: audioPath != null && File(audioPath).existsSync()
            ? p.normalize(audioPath)
            : (listBookRootAudioFiles(book).isNotEmpty
                ? listBookRootAudioFiles(book).first
                : book),
        dryRun: dryRun,
        doSplit: doSplit,
        yes: yes,
        originalsDirName: originalsDir,
        showAllChapters: showAllChapters,
        fast: fast,
        forceLocate: forceLocate,
        fillMissing: fillMissing,
      ),
    );
    stdout.writeln(
      '\nDone. strategy=${result.strategy} cuts=${result.cuts.length} '
      'missing=${result.missing.length}',
    );
  } catch (e, st) {
    stderr.writeln('structure failed: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

