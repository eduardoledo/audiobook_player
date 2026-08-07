import '../models/detected_marker.dart';

/// Matches Spanish/English structure keywords in ASR transcripts.
class KeywordChapterMatcher {
  static final _normalizeMap = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    _normalizeMap.forEach((k, v) {
      s = s.replaceAll(k, v);
    });
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Number words / roman numerals accepted for chapter indices.
  static const _numberWordAlt =
      r'uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|'
      r'once|doce|trece|catorce|quince|dieciseis|diecisiete|dieciocho|diecinueve|veinte|'
      r'veintiuno|veintidos|veintitres|veinticuatro|veinticinco|'
      r'treinta|cuarenta|cincuenta|'
      r'one|two|three|four|five|six|seven|eight|nine|ten|'
      r'eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|'
      r'thirty|forty|fifty|'
      r'i{1,3}|iv|v|vi{0,3}|ix|x|xi|xii|xiii|xiv|xv';

  /// Entire transcript is only a chapter number (digit, word, or roman).
  static final _bareNumberOnly = RegExp(
    '^(\\d{1,3}|$_numberWordAlt)\$',
  );

  static final _patterns = <(MarkerType, RegExp, String Function(RegExpMatch))>[
    (
      MarkerType.end,
      RegExp(
        r'\b(fin del (capitulo|prologo|epilogo)|end of (chapter|prologue|epilogue))\b',
      ),
      (m) => m.group(0)!,
    ),
    (
      MarkerType.epilogue,
      RegExp(r'\b(epilogo|epilogue|afterword|nota final|conclusion)\b'),
      (_) => 'Epílogo',
    ),
    (
      MarkerType.prologue,
      RegExp(r'\b(prologo|prologue|preface|prefacio|introduccion|introduction)\b'),
      (_) => 'Prólogo',
    ),
    (
      MarkerType.part,
      RegExp(
        r'\b(?:parte|part)\s+(primera|segunda|tercera|cuarta|quinta|first|second|third|fourth|fifth|\d+|i{1,3}|iv|v)\b'
        r'|\bbook\s+(\d+)\b',
      ),
      (m) {
        final n = m.group(1) ?? m.group(2) ?? '';
        return 'Parte $n';
      },
    ),
    (
      MarkerType.chapter,
      RegExp(
        '\\b(?:capitulo|chapter)\\s+(\\d+|$_numberWordAlt)\\b',
      ),
      (m) {
        final n = m.group(1) ?? '';
        return 'Capítulo ${_wordToNumber(n)}';
      },
    ),
  ];

  static final _numberMap = <String, String>{
    'uno': '1',
    'dos': '2',
    'tres': '3',
    'cuatro': '4',
    'cinco': '5',
    'seis': '6',
    'siete': '7',
    'ocho': '8',
    'nueve': '9',
    'diez': '10',
    'once': '11',
    'doce': '12',
    'trece': '13',
    'catorce': '14',
    'quince': '15',
    'dieciseis': '16',
    'diecisiete': '17',
    'dieciocho': '18',
    'diecinueve': '19',
    'veinte': '20',
    'veintiuno': '21',
    'veintidos': '22',
    'veintitres': '23',
    'veinticuatro': '24',
    'veinticinco': '25',
    'treinta': '30',
    'cuarenta': '40',
    'cincuenta': '50',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
    'thirteen': '13',
    'fourteen': '14',
    'fifteen': '15',
    'sixteen': '16',
    'seventeen': '17',
    'eighteen': '18',
    'nineteen': '19',
    'twenty': '20',
    'thirty': '30',
    'forty': '40',
    'fifty': '50',
    'i': '1',
    'ii': '2',
    'iii': '3',
    'iv': '4',
    'v': '5',
    'vi': '6',
    'vii': '7',
    'viii': '8',
    'ix': '9',
    'x': '10',
    'xi': '11',
    'xii': '12',
    'xiii': '13',
    'xiv': '14',
    'xv': '15',
    'primera': '1',
    'segunda': '2',
    'tercera': '3',
    'first': '1',
    'second': '2',
    'third': '3',
  };

  static String _wordToNumber(String raw) {
    final key = raw.toLowerCase();
    return _numberMap[key] ?? raw;
  }

  /// Parses the chapter index from a label like `Capítulo 12`, or null.
  static int? parseChapterNumber(String label) {
    final m = RegExp(r'(\d+)').firstMatch(label);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  /// Priority when multiple patterns match the same text.
  static int _priority(MarkerType t) => switch (t) {
        MarkerType.epilogue => 4,
        MarkerType.prologue => 3,
        MarkerType.part => 2,
        MarkerType.chapter => 1,
        MarkerType.end => 0,
      };

  /// Returns the best marker in [transcript] at absolute [positionMs], or null.
  DetectedMarker? match(String transcript, int positionMs) {
    final text = normalize(transcript);
    if (text.isEmpty) return null;

    DetectedMarker? best;
    for (final (type, pattern, labelFn) in _patterns) {
      final m = pattern.firstMatch(text);
      if (m == null) continue;
      final candidate = DetectedMarker(
        type: type,
        label: labelFn(m),
        positionMs: positionMs,
        confidence: 0.85,
        rawText: transcript.trim(),
      );
      if (best == null || _priority(type) > _priority(best.type)) {
        best = candidate;
      }
    }

    // Narrators sometimes say only the number ("tres", "12").
    if (best == null) {
      final bare = _bareNumberOnly.firstMatch(text);
      if (bare != null) {
        final n = _wordToNumber(bare.group(1)!);
        if (RegExp(r'^\d+$').hasMatch(n)) {
          final num = int.parse(n);
          if (num >= 1 && num <= 200) {
            best = DetectedMarker(
              type: MarkerType.chapter,
              label: 'Capítulo $n',
              positionMs: positionMs,
              confidence: 0.55,
              rawText: transcript.trim(),
            );
          }
        }
      }
    }

    return best;
  }

  /// Deduplicate markers that are too close (< [minGapMs]).
  List<DetectedMarker> dedupe(
    List<DetectedMarker> markers, {
    int minGapMs = 8000,
  }) {
    final sorted = List<DetectedMarker>.from(markers)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
    final out = <DetectedMarker>[];
    for (final m in sorted) {
      if (out.isEmpty) {
        out.add(m);
        continue;
      }
      final prev = out.last;
      if (m.positionMs - prev.positionMs < minGapMs) {
        if (_preferOver(m, prev)) {
          out[out.length - 1] = m;
        }
        continue;
      }
      out.add(m);
    }
    return validateChapterSequence(out);
  }

  /// Prefer keyword chapters over bare-number ones; else higher type priority.
  static bool _preferOver(DetectedMarker a, DetectedMarker b) {
    if (a.type == MarkerType.chapter && b.type == MarkerType.chapter) {
      if ((a.confidence - b.confidence).abs() > 0.05) {
        return a.confidence > b.confidence;
      }
    }
    return _priority(a.type) > _priority(b.type);
  }

  /// Keeps a coherent increasing chapter-number sequence.
  ///
  /// Bare-number detections (lower confidence) are only kept when they match
  /// the expected next chapter. Keyword detections may skip a small gap.
  List<DetectedMarker> validateChapterSequence(List<DetectedMarker> markers) {
    final sorted = List<DetectedMarker>.from(markers)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

    final out = <DetectedMarker>[];
    var lastChapterNum = 0;

    for (final m in sorted) {
      if (m.type != MarkerType.chapter) {
        out.add(m);
        continue;
      }

      final num = parseChapterNumber(m.label);
      if (num == null) {
        // Non-numeric chapter label: keep as-is
        out.add(m);
        continue;
      }

      final isBare = m.confidence < 0.7;
      final expected = lastChapterNum + 1;

      if (lastChapterNum == 0) {
        // First chapter: prefer 1, but allow keyword start at any small n
        if (isBare && num != 1 && num > 3) {
          continue; // bare "47" alone as first hit is likely noise
        }
        out.add(m);
        lastChapterNum = num;
        continue;
      }

      if (num == lastChapterNum) {
        // Duplicate announcement — keep higher confidence
        final prevIdx = out.lastIndexWhere((e) => e.type == MarkerType.chapter);
        if (prevIdx >= 0 && m.confidence > out[prevIdx].confidence) {
          out[prevIdx] = m;
        }
        continue;
      }

      if (num < lastChapterNum) {
        // Regression: ignore (out of order / false positive)
        continue;
      }

      // Forward jump
      final gap = num - lastChapterNum;
      if (isBare) {
        // Bare numbers must be exactly the next chapter
        if (num != expected) continue;
      } else {
        // Keyword matches can skip a few missed chapters
        if (gap > 5) continue;
      }

      out.add(m);
      lastChapterNum = num;
    }

    return out;
  }

  /// Increasing chapter anchors (by time) used to detect skipped numbers.
  static List<({int number, int positionMs})> increasingChapterAnchors(
    List<DetectedMarker> markers,
  ) {
    final chapters = markers
        .where((m) => m.type == MarkerType.chapter)
        .toList()
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

    final anchors = <({int number, int positionMs})>[];
    for (final m in chapters) {
      final n = parseChapterNumber(m.label);
      if (n == null) continue;
      if (anchors.isEmpty || n > anchors.last.number) {
        anchors.add((number: n, positionMs: m.positionMs));
      }
    }
    return anchors;
  }

  /// Gaps where chapter numbers jump forward (e.g. 2 → 5 means missing 3,4).
  static List<ChapterNumberGap> findChapterGaps(List<DetectedMarker> markers) {
    final anchors = increasingChapterAnchors(markers);
    final gaps = <ChapterNumberGap>[];
    for (var i = 0; i + 1 < anchors.length; i++) {
      final a = anchors[i];
      final b = anchors[i + 1];
      if (b.number > a.number + 1 && b.positionMs > a.positionMs + 1500) {
        gaps.add(ChapterNumberGap(
          fromNumber: a.number,
          toNumber: b.number,
          fromPositionMs: a.positionMs,
          toPositionMs: b.positionMs,
        ));
      }
    }
    return gaps;
  }

  /// Like [match], but only accepts chapter markers whose number is in [expected].
  DetectedMarker? matchExpected(
    String transcript,
    int positionMs,
    Set<int> expected,
  ) {
    if (expected.isEmpty) return null;
    final m = match(transcript, positionMs);
    if (m == null || m.type != MarkerType.chapter) return null;
    final n = parseChapterNumber(m.label);
    if (n == null || !expected.contains(n)) return null;
    // Slight boost so sequence validation treats filled hits as reliable.
    return m.copyWith(confidence: m.confidence < 0.7 ? 0.72 : m.confidence);
  }
}

/// A skipped range between two detected chapter numbers.
class ChapterNumberGap {
  final int fromNumber;
  final int toNumber;
  final int fromPositionMs;
  final int toPositionMs;

  const ChapterNumberGap({
    required this.fromNumber,
    required this.toNumber,
    required this.fromPositionMs,
    required this.toPositionMs,
  });

  List<int> get missingNumbers => [
        for (var n = fromNumber + 1; n < toNumber; n++) n,
      ];
}
