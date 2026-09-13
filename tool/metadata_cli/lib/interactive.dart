import 'dart:io';

import 'book_metadata.dart' show adjustPartTitles;
import 'catalog.dart';
import 'models.dart';

void printMetadata(BookMetadata meta, {String? path}) {
  if (path != null) {
    stdout.writeln('Path: $path');
  }
  final entryLabel = meta.isPart ? 'part (parte de un libro)' : 'book (libro)';
  stdout.writeln('  entryType:       $entryLabel');
  stdout.writeln('  title:           ${meta.title}');
  stdout.writeln('  author:          ${meta.author}');
  stdout.writeln(
    '  narrator:        ${meta.blankKeys.contains("narrator") ? "(blank)" : (meta.narrator ?? "")}',
  );
  stdout.writeln(
    '  universe:        ${meta.blankKeys.contains("universe") ? "(blank)" : (meta.universe ?? "")}',
  );
  stdout.writeln(
    '  seriesName:      ${meta.blankKeys.contains("seriesName") ? "(blank)" : (meta.seriesName ?? "")}',
  );
  stdout.writeln(
    '  seriesPosition:  ${meta.blankKeys.contains("seriesPosition") ? "(blank)" : (meta.seriesPosition ?? "")}',
  );
  stdout.writeln(
    '  universeOrder:   ${meta.blankKeys.contains("universeOrder") ? "(blank)" : (meta.universeOrder ?? "")}',
  );
  if (meta.era != null && meta.era!.isNotEmpty) {
    stdout.writeln('  era:             ${meta.era}');
  }
  if (meta.readingOrderKey.isNotEmpty) {
    stdout.writeln('  readingOrderKey: ${meta.readingOrderKey}');
  }
  if (meta.isPart) {
    stdout.writeln(
      '  partOf:          ${meta.blankKeys.contains("partOf") ? "(blank)" : (meta.partOf ?? "")}',
    );
    stdout.writeln(
      '  partName:        ${meta.blankKeys.contains("partName") ? "(blank)" : (meta.partName ?? "")}',
    );
  }
  stdout.writeln('  publishYear:     ${meta.publishYear ?? ""}');
  stdout.writeln(
    '  subjects:        ${meta.subjects.isEmpty ? "" : meta.subjects.join(", ")}',
  );
  stdout.writeln('  duration:        ${meta.durationFormatted}');
  if (meta.parts.isNotEmpty) {
    stdout.writeln('  parts:           ${meta.parts.length}');
    for (final part in meta.parts) {
      final orderLabel = part.order != null ? '#${part.order} ' : '';
      stdout.writeln(
        '    - $orderLabel${part.name} (${part.durationFormatted ?? "?"} )',
      );
    }
  }
  if (meta.chapters.isNotEmpty) {
    stdout.writeln('  chapters:        ${meta.chapters.length}');
    final preview = meta.chapters.length > 8 ? 5 : meta.chapters.length;
    for (var i = 0; i < preview; i++) {
      final raw = meta.chapters[i];
      final label = raw is Map
          ? (raw['displayTitle'] ?? raw['title'] ?? '#${i + 1}').toString()
          : '#${i + 1}';
      stdout.writeln('    - $label');
    }
    if (meta.chapters.length > preview) {
      stdout.writeln('    … +${meta.chapters.length - preview} more');
    }
  }
  final desc = meta.description ?? '';
  if (desc.isEmpty) {
    stdout.writeln('  description:     ');
  } else {
    final preview = desc.length > 120
        ? '${desc.substring(0, 120).replaceAll('\n', ' ')}…'
        : desc;
    stdout.writeln('  description:     $preview');
  }
}

Future<String> _readLine(String prompt) async {
  stdout.write(prompt);
  return stdin.readLineSync()?.trim() ?? '';
}

/// Interactive edit loop. Returns null if user skips/quits without saving.
Future<BookMetadata?> interactiveEdit(
  BookMetadata meta, {
  required String path,
  MetadataCatalog? catalog,
}) async {
  var current = meta.copy();
  final cat = catalog ?? MetadataCatalog();

  while (true) {
    stdout.writeln('');
    stdout.writeln('─' * 60);
    printMetadata(current, path: path);
    stdout.writeln('─' * 60);
    stdout.writeln(
      '[Enter] save  |  e edit field  |  s skip  |  q quit',
    );
    final action = await _readLine('> ');

    if (action.isEmpty) {
      return current;
    }
    if (action == 's' || action == 'S') {
      return null;
    }
    if (action == 'q' || action == 'Q') {
      throw const _QuitException();
    }
    if (action == 'e' || action == 'E') {
      current = await _editFields(current, cat, path: path);
      continue;
    }
    stdout.writeln('Unknown action: $action');
  }
}

const _autocompleteFields = {
  'author',
  'narrator',
  'universe',
  'seriesName',
  'partOf',
};

const _fieldAliases = <String, String>{
  't': 'title',
  'a': 'author',
  'n': 'narrator',
  'narr': 'narrator',
  'u': 'universe',
  's': 'seriesName',
  'series': 'seriesName',
  'saga': 'seriesName',
  'pos': 'seriesPosition',
  'position': 'seriesPosition',
  'seq': 'seriesPosition',
  'sequence': 'seriesPosition',
  'uo': 'universeOrder',
  'uorder': 'universeOrder',
  'universeorder': 'universeOrder',
  'type': 'entryType',
  'kind': 'entryType',
  'entry': 'entryType',
  'libro': 'entryType',
  'parte': 'entryType',
  'parent': 'partOf',
  'partof': 'partOf',
  'pname': 'partName',
  'y': 'publishYear',
  'year': 'publishYear',
  'd': 'description',
  'desc': 'description',
  'sub': 'subjects',
  'tags': 'subjects',
};

Future<BookMetadata> _editFields(
  BookMetadata meta,
  MetadataCatalog catalog, {
  required String path,
}) async {
  final fieldNames = <String>[
    'entryType',
    'title',
    'author',
    'narrator',
    'universe',
    'seriesName',
    'seriesPosition',
    'universeOrder',
    if (meta.isPart) 'partOf',
    if (meta.isPart) 'partName',
    'publishYear',
    'description',
    'subjects',
  ];

  final field = await _pickFieldName(fieldNames);
  if (field == null) {
    stdout.writeln('Cancelled.');
    return meta;
  }

  if (field == 'entryType') {
    final chosen = await _pickEntryType(meta.entryType);
    if (chosen != null) {
      final wasPart = meta.isPart;
      meta.entryType = chosen;
      if (!meta.isPart) {
        // Switching back to book: clear part-only fields unless blank-locked.
        if (!meta.blankKeys.contains('partOf')) meta.partOf = null;
        if (!meta.blankKeys.contains('partName')) meta.partName = null;
      } else if (!wasPart) {
        // Book → part: if title was the part folder name, fix title/partOf/partName.
        adjustPartTitles(meta, bookPath: path);
      }
    }
    return meta;
  }

  final clearable = BookMetadata.clearableKeys.contains(field);
  String value;
  if (_autocompleteFields.contains(field)) {
    value = await _readWithSuggestions(
      field: field,
      currentValue: _currentFieldValue(meta, field),
      catalog: catalog,
      author: meta.author,
      allowClear: clearable,
    );
  } else {
    final current = _currentFieldValue(meta, field);
    if (current.isNotEmpty) {
      stdout.writeln('Current: $current');
    }
    if (clearable) {
      stdout.writeln('Enter "-" or leave empty to clear this field.');
    }
    value = await _readLine('New value for $field: ');
    if (value == '-') value = '';
  }

  switch (field) {
    case 'title':
      if (value.isNotEmpty) meta.title = value;
      break;
    case 'author':
      if (value.isNotEmpty) meta.author = value;
      break;
    case 'narrator':
      meta.setClearable('narrator', value);
      break;
    case 'universe':
      meta.setClearable('universe', value);
      break;
    case 'seriesName':
      meta.setClearable('seriesName', value);
      break;
    case 'seriesPosition':
      meta.setClearable('seriesPosition', value);
      break;
    case 'universeOrder':
      meta.setClearable('universeOrder', value);
      break;
    case 'partOf':
      meta.setClearable('partOf', value);
      break;
    case 'partName':
      meta.setClearable('partName', value);
      break;
    case 'publishYear':
      meta.publishYear = value.isEmpty ? null : value;
      break;
    case 'description':
      meta.description = value.isEmpty ? null : value;
      break;
    case 'subjects':
      if (value.isEmpty) {
        meta.subjects = [];
      } else {
        meta.subjects = value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      break;
    default:
      stdout.writeln('Unknown field: $field');
  }
  return meta;
}

Future<String?> _pickEntryType(String current) async {
  stdout.writeln('');
  stdout.writeln('Tipo de entrada (actual: $current):');
  stdout.writeln('  1) book  — audiolibro completo');
  stdout.writeln('  2) part  — parte / disco / CD de un libro');
  stdout.writeln('Empty keeps current.');
  final input = await _readLine('entryType> ');
  if (input.isEmpty) return null;
  if (input == '1' || input.toLowerCase() == 'book' || input.toLowerCase() == 'libro') {
    return 'book';
  }
  if (input == '2' ||
      input.toLowerCase() == 'part' ||
      input.toLowerCase() == 'parte') {
    return 'part';
  }
  return BookMetadata.normalizeEntryType(input);
}

/// Pick a metadata field by number, alias, or unique prefix.
Future<String?> _pickFieldName(List<String> fieldNames) async {
  var filter = '';
  while (true) {
    final suggestions = filter.isEmpty
        ? fieldNames
        : fieldNames
            .where((f) => f.toLowerCase().contains(filter.toLowerCase()))
            .toList();

    stdout.writeln('');
    stdout.writeln(
      'Fields${filter.isEmpty ? "" : " filtered by \"$filter\""}:',
    );
    if (suggestions.isEmpty) {
      stdout.writeln('  (none)');
    } else {
      for (var i = 0; i < suggestions.length; i++) {
        stdout.writeln('  ${i + 1}) ${suggestions[i]}');
      }
    }
    stdout.writeln(
      '# pick  |  name/prefix  |  /texto filter  |  empty cancel',
    );

    final input = await _readLine('field> ');
    if (input.isEmpty) return null;

    if (input.startsWith('/') && input.length > 1) {
      filter = input.substring(1).trim();
      continue;
    }
    if (input == '/') {
      filter = '';
      continue;
    }

    final asNumber = int.tryParse(input);
    if (asNumber != null) {
      if (asNumber >= 1 && asNumber <= suggestions.length) {
        return suggestions[asNumber - 1];
      }
      stdout.writeln('Invalid number. Choose 1–${suggestions.length}.');
      continue;
    }

    final lower = input.toLowerCase();
    final alias = _fieldAliases[lower];
    if (alias != null && fieldNames.contains(alias)) {
      return alias;
    }

    for (final name in suggestions) {
      if (name.toLowerCase() == lower) return name;
    }

    final prefixMatches = suggestions
        .where((f) => f.toLowerCase().startsWith(lower))
        .toList();
    if (prefixMatches.length == 1) return prefixMatches.first;
    if (prefixMatches.length > 1) {
      filter = input;
      continue;
    }

    final containsMatches = suggestions
        .where((f) => f.toLowerCase().contains(lower))
        .toList();
    if (containsMatches.length == 1) return containsMatches.first;
    if (containsMatches.length > 1) {
      filter = input;
      continue;
    }

    stdout.writeln('Unknown field: $input');
  }
}

String _currentFieldValue(BookMetadata meta, String field) {
  switch (field) {
    case 'title':
      return meta.title;
    case 'author':
      return meta.author;
    case 'narrator':
      return meta.narrator ?? '';
    case 'universe':
      return meta.universe ?? '';
    case 'seriesName':
      return meta.seriesName ?? '';
    case 'seriesPosition':
      return meta.seriesPosition ?? '';
    case 'universeOrder':
      return meta.universeOrder ?? '';
    case 'partOf':
      return meta.partOf ?? '';
    case 'partName':
      return meta.partName ?? '';
    case 'entryType':
      return meta.entryType;
    case 'publishYear':
      return meta.publishYear ?? '';
    case 'description':
      return meta.description ?? '';
    case 'subjects':
      return meta.subjects.join(', ');
    default:
      return '';
  }
}

/// Pick a known value by number, filter with `/texto`, or type a new value.
Future<String> _readWithSuggestions({
  required String field,
  required String currentValue,
  required MetadataCatalog catalog,
  required String author,
  bool allowClear = false,
}) async {
  var filter = '';
  while (true) {
    final suggestions = catalog.suggestionsFor(
      field,
      author: author.isNotEmpty ? author : null,
      prefix: filter.isEmpty ? null : filter,
    );

    stdout.writeln('');
    final scope = field == 'author'
        ? ''
        : (author.isNotEmpty ? ' (for author: $author)' : '');
    stdout.writeln(
      'Known $field$scope'
      '${filter.isEmpty ? "" : " filtered by \"$filter\""}:',
    );
    if (suggestions.isEmpty) {
      stdout.writeln('  (none)');
    } else {
      final limit = suggestions.length > 25 ? 25 : suggestions.length;
      for (var i = 0; i < limit; i++) {
        stdout.writeln('  ${i + 1}) ${suggestions[i]}');
      }
      if (suggestions.length > limit) {
        stdout.writeln(
          '  … +${suggestions.length - limit} more — filter with /texto',
        );
      }
    }
    if (currentValue.isNotEmpty) {
      stdout.writeln('Current: $currentValue');
    } else if (allowClear) {
      stdout.writeln('Current: (blank)');
    }
    stdout.writeln(
      allowClear
          ? '# pick  |  /texto filter  |  typed value  |  - clear  |  empty keep'
          : '# pick  |  /texto filter  |  typed value  |  empty keep current',
    );

    final input = await _readLine('$field> ');
    if (input.isEmpty) {
      return currentValue;
    }
    if (allowClear && input == '-') {
      return '';
    }

    if (input.startsWith('/') && input.length > 1) {
      filter = input.substring(1).trim();
      continue;
    }
    if (input == '/') {
      filter = '';
      continue;
    }

    final asNumber = int.tryParse(input);
    if (asNumber != null) {
      if (asNumber >= 1 && asNumber <= suggestions.length) {
        return suggestions[asNumber - 1];
      }
      stdout.writeln('Invalid number. Choose 1–${suggestions.length}.');
      continue;
    }

    for (final s in suggestions) {
      if (s.toLowerCase() == input.toLowerCase()) return s;
    }
    final uniquePrefix = suggestions
        .where((s) => s.toLowerCase().startsWith(input.toLowerCase()))
        .toList();
    if (uniquePrefix.length == 1) return uniquePrefix.first;

    return input;
  }
}

class _QuitException implements Exception {
  const _QuitException();
}

bool isQuitException(Object e) => e is _QuitException;
