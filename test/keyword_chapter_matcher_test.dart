import 'package:audiobook_player/models/detected_marker.dart';
import 'package:audiobook_player/services/keyword_chapter_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KeywordChapterMatcher matcher;

  setUp(() {
    matcher = KeywordChapterMatcher();
  });

  group('KeywordChapterMatcher', () {
    test('detects Spanish capítulo', () {
      final m = matcher.match('Capítulo 3 El imperio final', 120000);
      expect(m, isNotNull);
      expect(m!.type, MarkerType.chapter);
      expect(m.label, contains('3'));
      expect(m.positionMs, 120000);
    });

    test('detects English chapter', () {
      final m = matcher.match('Chapter 12 begins here', 0);
      expect(m, isNotNull);
      expect(m!.type, MarkerType.chapter);
      expect(m.label, contains('12'));
    });

    test('detects prólogo and prologue', () {
      expect(matcher.match('Este es el prólogo', 0)?.type, MarkerType.prologue);
      expect(matcher.match('Prologue', 0)?.type, MarkerType.prologue);
    });

    test('detects epílogo and epilogue', () {
      expect(matcher.match('Epílogo', 0)?.type, MarkerType.epilogue);
      expect(matcher.match('End of the epilogue section wait Epilogue', 0)?.type,
          MarkerType.epilogue);
    });

    test('detects parte', () {
      final m = matcher.match('Parte primera', 5000);
      expect(m?.type, MarkerType.part);
      expect(m?.label.toLowerCase(), contains('parte'));
    });

    test('priority prefers epilogue over chapter words in same text', () {
      final m = matcher.match('Chapter notes and Epilogue', 0);
      expect(m?.type, MarkerType.epilogue);
    });

    test('dedupe keeps higher priority within gap', () {
      final a = DetectedMarker(
        type: MarkerType.chapter,
        label: 'Capítulo 1',
        positionMs: 1000,
      );
      final b = DetectedMarker(
        type: MarkerType.prologue,
        label: 'Prólogo',
        positionMs: 2000,
      );
      final out = matcher.dedupe([a, b], minGapMs: 8000);
      expect(out.length, 1);
      expect(out.first.type, MarkerType.prologue);
    });

    test('detects bare spoken number as chapter', () {
      final m = matcher.match('tres', 90000);
      expect(m, isNotNull);
      expect(m!.type, MarkerType.chapter);
      expect(m.label, 'Capítulo 3');
      expect(m.confidence, lessThan(0.7));
    });

    test('detects bare digit as chapter', () {
      final m = matcher.match('12', 0);
      expect(m?.label, 'Capítulo 12');
    });

    test('validateChapterSequence keeps increasing numbers', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 1',
          positionMs: 1000,
          confidence: 0.85,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 2',
          positionMs: 20000,
          confidence: 0.55,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 5',
          positionMs: 40000,
          confidence: 0.55, // bare — gap too large, drop
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 3',
          positionMs: 60000,
          confidence: 0.55,
        ),
      ];
      final out = matcher.validateChapterSequence(markers);
      expect(out.map((m) => m.label).toList(), [
        'Capítulo 1',
        'Capítulo 2',
        'Capítulo 3',
      ]);
    });

    test('validateChapterSequence drops regressions', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 4',
          positionMs: 1000,
          confidence: 0.85,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 2',
          positionMs: 20000,
          confidence: 0.85,
        ),
      ];
      final out = matcher.validateChapterSequence(markers);
      expect(out.length, 1);
      expect(out.first.label, 'Capítulo 4');
    });

    test('keyword match may skip a small gap', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 1',
          positionMs: 1000,
          confidence: 0.85,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 4',
          positionMs: 20000,
          confidence: 0.85,
        ),
      ];
      final out = matcher.validateChapterSequence(markers);
      expect(out.length, 2);
    });

    test('dedupe applies chapter sequence validation', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 1',
          positionMs: 0,
          confidence: 0.85,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 99',
          positionMs: 30000,
          confidence: 0.55,
        ),
      ];
      final out = matcher.dedupe(markers, minGapMs: 8000);
      expect(out.length, 1);
      expect(out.first.label, 'Capítulo 1');
    });

    test('chaptersFromMarkers builds contiguous chapters', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.prologue,
          label: 'Prólogo',
          positionMs: 0,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 1',
          positionMs: 60000,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 2',
          positionMs: 120000,
        ),
      ];
      final chapters = chaptersFromMarkers(markers, 180.0, (s) => s.toString());
      expect(chapters.length, 3);
      expect(chapters[0].start, 0);
      expect(chapters[0].end, 60);
      expect(chapters[2].end, 180);
    });

    test('findChapterGaps detects skipped numbers', () {
      final markers = [
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 1',
          positionMs: 0,
          confidence: 0.85,
        ),
        const DetectedMarker(
          type: MarkerType.chapter,
          label: 'Capítulo 4',
          positionMs: 120000,
          confidence: 0.85,
        ),
      ];
      final gaps = KeywordChapterMatcher.findChapterGaps(markers);
      expect(gaps.length, 1);
      expect(gaps.first.missingNumbers, [2, 3]);
      expect(gaps.first.fromPositionMs, 0);
      expect(gaps.first.toPositionMs, 120000);
    });

    test('matchExpected only accepts listed chapter numbers', () {
      final ok = matcher.matchExpected('Capítulo 3', 5000, {2, 3});
      expect(ok?.label, 'Capítulo 3');
      final no = matcher.matchExpected('Capítulo 9', 5000, {2, 3});
      expect(no, isNull);
      final bare = matcher.matchExpected('dos', 5000, {2});
      expect(bare?.label, 'Capítulo 2');
      expect(bare!.confidence, greaterThanOrEqualTo(0.7));
    });
  });
}
