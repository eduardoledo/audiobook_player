import 'dart:io';

import 'package:path/path.dart' as p;

import 'epub_structure.dart';
import 'models.dart';
import 'structure_match.dart';

const _audioExt = {
  '.m4b',
  '.m4a',
  '.mp3',
  '.flac',
  '.ogg',
  '.opus',
  '.aac',
};

/// True when [meta] has ≥2 chapters with usable start/end times.
bool hasUsableSavedTimeline(BookMetadata? meta) {
  return cutsFromSavedMetadata(meta) != null;
}

/// Builds [AlignedChapterCut]s from `book.metadata.json` chapter timeline.
///
/// Returns null when chapters are missing, lack times, or are not ordered.
/// [minChapters] defaults to 2 (enough to split); use 1 to resume a partial locate.
List<AlignedChapterCut>? cutsFromSavedMetadata(
  BookMetadata? meta, {
  int minChapters = 2,
}) {
  if (meta == null || meta.chapters.length < minChapters) return null;

  final cuts = <AlignedChapterCut>[];
  double? prevEnd;
  for (var i = 0; i < meta.chapters.length; i++) {
    final raw = meta.chapters[i];
    if (raw is! Map) return null;
    final start = _asSeconds(raw['start'] ?? raw['startSeconds']);
    final end = _asSeconds(raw['end'] ?? raw['endSeconds']);
    if (start == null || end == null) return null;
    if (end - start < 0.5) return null;
    if (prevEnd != null && start + 0.05 < prevEnd) return null;
    prevEnd = end;

    final title = (raw['title'] ?? raw['displayTitle'] ?? 'Chapter ${i + 1}')
        .toString()
        .trim();
    final partRaw = raw['part']?.toString().trim();
    final part = (partRaw == null || partRaw.isEmpty) ? null : partRaw;
    final kind = _guessKind(title);
    cuts.add(
      AlignedChapterCut(
        epub: EpubTocEntry(
          title: title.isEmpty ? 'Chapter ${i + 1}' : title,
          href: '',
          kind: kind,
          chapterNumber: _chapterNumber(title),
          part: part,
          firstWords: '',
          firstWordsNormalized: const [],
          wordCount: 0,
        ),
        startSeconds: start,
        endSeconds: end,
      ),
    );
  }
  return cuts;
}

/// Aligns saved timeline cuts onto [epub] entries (sequential title match).
///
/// Result length equals [epub.entries]; null slots are not yet located.
List<AlignedChapterCut?> alignSavedCutsToEpub({
  required List<AlignedChapterCut> saved,
  required EpubStructure epub,
}) {
  final out = List<AlignedChapterCut?>.filled(epub.entries.length, null);
  if (saved.isEmpty || epub.entries.isEmpty) return out;

  var si = 0;
  for (var ei = 0; ei < epub.entries.length && si < saved.length; ei++) {
    final entry = epub.entries[ei];
    if (!chapterTitlesAlign(entry, saved[si].epub.title)) continue;
    final part = saved[si].epub.part ?? entry.part;
    out[ei] = AlignedChapterCut(
      epub: entry.copyWith(part: part),
      startSeconds: saved[si].startSeconds,
      endSeconds: saved[si].endSeconds,
    );
    si++;
  }

  // Match any leftover saved chapters by title (gaps in the middle).
  if (si < saved.length) {
    for (; si < saved.length; si++) {
      for (var ei = 0; ei < epub.entries.length; ei++) {
        if (out[ei] != null) continue;
        if (!chapterTitlesAlign(epub.entries[ei], saved[si].epub.title)) {
          continue;
        }
        final entry = epub.entries[ei];
        final part = saved[si].epub.part ?? entry.part;
        out[ei] = AlignedChapterCut(
          epub: entry.copyWith(part: part),
          startSeconds: saved[si].startSeconds,
          endSeconds: saved[si].endSeconds,
        );
        break;
      }
    }
  }
  return out;
}

int countAlignedCuts(List<AlignedChapterCut?> aligned) =>
    aligned.where((c) => c != null).length;

bool alignedCoversAll(List<AlignedChapterCut?> aligned) =>
    aligned.isNotEmpty && aligned.every((c) => c != null);

/// Audio files in the book folder root (not under [originalsDirName]).
List<String> listBookRootAudioFiles(
  String bookPath, {
  String originalsDirName = 'originals',
}) {
  final dir = Directory(bookPath);
  if (!dir.existsSync()) return const [];
  final originals = p.normalize(p.join(bookPath, originalsDirName));
  final out = <String>[];
  for (final e in dir.listSync(followLinks: false)) {
    if (e is! File) continue;
    final path = p.normalize(e.path);
    if (path == originals || p.isWithin(originals, path)) continue;
    final ext = p.extension(path).toLowerCase();
    if (_audioExt.contains(ext)) out.add(path);
  }
  out.sort();
  return out;
}

/// True when the book already has multiple chapter audio files in its root.
bool isBookAudioAlreadySplit(
  String bookPath, {
  String originalsDirName = 'originals',
}) {
  return listBookRootAudioFiles(
        bookPath,
        originalsDirName: originalsDirName,
      ).length >=
      2;
}

/// Attach EPUB part labels onto saved cuts when possible.
List<AlignedChapterCut> enrichCutsWithEpubParts({
  required List<AlignedChapterCut> cuts,
  required EpubStructure epub,
}) {
  if (epub.entries.isEmpty) return cuts;
  final byNumber = <int, EpubTocEntry>{};
  final byTitle = <String, EpubTocEntry>{};
  for (final e in epub.entries) {
    if (e.chapterNumber != null) byNumber[e.chapterNumber!] = e;
    byTitle[_normTitle(e.title)] = e;
  }

  final out = <AlignedChapterCut>[];
  for (final cut in cuts) {
    final n = cut.epub.chapterNumber;
    final match =
        (n != null ? byNumber[n] : null) ?? byTitle[_normTitle(cut.epub.title)];
    if (match == null || match.part == null || match.part!.isEmpty) {
      out.add(cut);
      continue;
    }
    out.add(
      AlignedChapterCut(
        epub: cut.epub.copyWith(part: match.part),
        startSeconds: cut.startSeconds,
        endSeconds: cut.endSeconds,
      ),
    );
  }
  return out;
}

double? _asSeconds(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final asNum = double.tryParse(t);
    if (asNum != null) return asNum;
    return _parseFormatted(t);
  }
  return null;
}

double? _parseFormatted(String s) {
  final parts = s.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final nums = <double>[];
  for (final p in parts) {
    final v = double.tryParse(p);
    if (v == null) return null;
    nums.add(v);
  }
  if (nums.length == 2) return nums[0] * 60 + nums[1];
  return nums[0] * 3600 + nums[1] * 60 + nums[2];
}

EpubEntryKind _guessKind(String title) {
  final t = title.trim().toLowerCase();
  if (t.startsWith('prologue') || t == 'prólogo' || t == 'prologo') {
    return EpubEntryKind.prologue;
  }
  if (t.startsWith('epilogue') || t == 'epílogo' || t == 'epilogo') {
    return EpubEntryKind.epilogue;
  }
  if (RegExp(r'^(chapter|cap[ií]tulo)\s*\d+', caseSensitive: false)
      .hasMatch(t)) {
    return EpubEntryKind.chapter;
  }
  return EpubEntryKind.other;
}

int? _chapterNumber(String title) {
  final m = RegExp(
    r'^(?:chapter|cap[ií]tulo)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(title.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String _normTitle(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
