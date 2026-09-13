import 'package:audiobook_player/bloc/home_cubit.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:flutter_test/flutter_test.dart';

Audiobook _book({
  required String path,
  required String title,
  String author = 'Author',
  String? universe,
  String? series,
  String? seriesSequence,
  String? publishYear,
  List<double> readingOrderKey = const [],
}) {
  return Audiobook(
    path: path,
    title: title,
    author: author,
    universe: universe,
    series: series,
    seriesSequence: seriesSequence,
    publishYear: publishYear,
    readingOrderKey: readingOrderKey,
    files: const ['a.mp3'],
    durationFormatted: '01:00:00.000',
    totalChapters: 1,
    chapters: const [],
  );
}

void main() {
  group('HomeCubit.compareLibraryOrder', () {
    test('orders by seriesSequence then year then title', () {
      final a = _book(path: '/a', title: 'B', seriesSequence: '2', publishYear: '2020');
      final b = _book(path: '/b', title: 'A', seriesSequence: '1', publishYear: '2019');
      final c = _book(path: '/c', title: 'C', seriesSequence: '2', publishYear: '2018');

      final list = [a, b, c]..sort(HomeCubit.compareLibraryOrder);
      expect(list.map((e) => e.path).toList(), ['/b', '/c', '/a']);
    });

    test('expands saga books before next universe item', () {
      final elantris = _book(
        path: '/e',
        title: 'Elantris',
        universe: 'Cosmere',
        seriesSequence: '01',
        readingOrderKey: const [1],
      );
      final finalEmpire = _book(
        path: '/fe',
        title: 'The Final Empire',
        universe: 'Cosmere',
        series: 'Mistborn',
        seriesSequence: '01',
        readingOrderKey: const [2, 1, 1],
      );
      final well = _book(
        path: '/wa',
        title: 'The Well of Ascension',
        universe: 'Cosmere',
        series: 'Mistborn',
        seriesSequence: '02',
        readingOrderKey: const [2, 1, 2],
      );
      final warbreaker = _book(
        path: '/w',
        title: 'Warbreaker',
        universe: 'Cosmere',
        seriesSequence: '03',
        readingOrderKey: const [3],
      );

      final list = [warbreaker, well, elantris, finalEmpire]
        ..sort(HomeCubit.compareLibraryOrder);
      expect(
        list.map((e) => e.title).toList(),
        [
          'Elantris',
          'The Final Empire',
          'The Well of Ascension',
          'Warbreaker',
        ],
      );
    });
  });
}
