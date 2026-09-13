import 'package:metadata_cli/chapters_from_files.dart';
import 'package:test/test.dart';

void main() {
  group('cleanChapterFileName', () {
    test('strips numeric prefixes', () {
      expect(cleanChapterFileName('01 - The Storm'), 'The Storm');
      expect(cleanChapterFileName('001. Arrival'), 'Arrival');
      expect(cleanChapterFileName('12_Nightfall'), 'Nightfall');
      expect(cleanChapterFileName('01|The Storm'), 'The Storm');
    });

    test('handles chapter/capitulo prefixes', () {
      expect(cleanChapterFileName('Chapter 02 - Arrival'), 'Arrival');
      expect(cleanChapterFileName('Capítulo 3 - El puente'), 'El puente');
      expect(cleanChapterFileName('Capitulo 4'), 'Capítulo 4');
      expect(cleanChapterFileName('Ch05 - Dawn'), 'Dawn');
      expect(cleanChapterFileName('Chapter 02|Arrival'), 'Arrival');
    });

    test('bare numbers become Capítulo N', () {
      expect(cleanChapterFileName('01'), 'Capítulo 1');
      expect(cleanChapterFileName('12'), 'Capítulo 12');
    });
  });

  group('extractPartFromFileName', () {
    test('detects CD/Part prefixes with dash or pipe', () {
      expect(extractPartFromFileName('CD1|01 - Intro')?.part, 'CD1');
      expect(extractPartFromFileName('CD1|01 - Intro')?.rest, '01 - Intro');
      expect(
        extractPartFromFileName('Part 2 - Chapter 1 - Storm')?.part,
        'Part 2',
      );
      expect(
        extractPartFromFileName('Part 2 - Chapter 1 - Storm')?.rest,
        'Chapter 1 - Storm',
      );
      expect(
        extractPartFromFileName('Parte 1|El puente')?.part,
        'Part 1 - El puente',
      );
    });

    test('detects Part I - N as part + chapter index', () {
      expect(extractPartFromFileName('Part I - 1')?.part, 'Part I');
      expect(extractPartFromFileName('Part I - 1')?.rest, 'Chapter 1');
      expect(extractPartFromFileName('Part III - 2')?.part, 'Part III');
      expect(extractPartFromFileName('Part III - 2')?.rest, 'Chapter 2');
      expect(extractPartFromFileName('Part II')?.part, 'Part II');
      expect(extractPartFromFileName('Part II')?.rest, '');
      expect(extractPartFromFileName('Part IV')?.part, 'Part IV');
    });

    test('detects literary Part I / Epilogue patterns', () {
      expect(
        extractPartFromFileName('1| Part I - Chapter 01')?.part,
        'Part I',
      );
      expect(
        extractPartFromFileName('1| Part I - Chapter 01')?.rest,
        'Chapter 01',
      );
      expect(
        extractPartFromFileName(
          '1| Part I - Come Together - Chapter 12',
        )?.part,
        'Part I - Come Together',
      );
      expect(
        extractPartFromFileName(
          '1| Part I - Come Together - Chapter 12',
        )?.rest,
        'Chapter 12',
      );
      expect(
        extractPartFromFileName('01 - Part I - Come Together')?.part,
        'Part I - Come Together',
      );
      expect(
        extractPartFromFileName('05 - Epilogue')?.part,
        'Epilogue',
      );
      expect(
        extractPartFromFileName('5| Epilogue - Chapter 53')?.part,
        'Epilogue',
      );
      expect(
        extractPartFromFileName('5| Epilogue - Chapter 53')?.rest,
        'Chapter 53',
      );
    });

    test('detects prologue/epilogue', () {
      expect(extractPartFromFileName('Prólogo|Opening')?.part, 'Prólogo');
      expect(extractPartFromFileName('Epilogue - Credits')?.part, 'Epilogue');
    });

    test('detects letter-prefixed epilogue and intro/proem', () {
      expect(
        extractPartFromFileName(
          'E| Epilogue - Interview With the Vampire - Chapter 1',
        )?.part,
        'Epilogue - Interview With the Vampire',
      );
      expect(
        extractPartFromFileName(
          'E| Epilogue - Interview With the Vampire - Chapter 1',
        )?.rest,
        'Chapter 1',
      );
      expect(extractPartFromFileName('0| Intro')?.part, 'Intro');
      expect(extractPartFromFileName('0| Proem')?.part, 'Proem');
    });
  });

  group('chapterNameFromAudioPath', () {
    test('detects part folder under book', () {
      final parsed = chapterNameFromAudioPath(
        '/lib/Author/Book/CD1/01 - Intro.mp3',
        bookPath: '/lib/Author/Book',
      );
      expect(parsed.part, 'CD1');
      expect(parsed.partPath, '/lib/Author/Book/CD1');
      expect(parsed.title, 'Intro');
    });

    test('detects nested part directory under book', () {
      final parsed = chapterNameFromAudioPath(
        '/lib/Author/Book/Parte 2/tracks/03 - Bridge.mp3',
        bookPath: '/lib/Author/Book',
      );
      expect(parsed.part, 'Part 2');
      expect(parsed.partPath, '/lib/Author/Book/Parte 2');
      expect(parsed.title, 'Bridge');
    });

    test('detects part embedded in directory name', () {
      final parsed = chapterNameFromAudioPath(
        '/lib/Author/Book/CD1|audio/01 - Intro.mp3',
        bookPath: '/lib/Author/Book',
      );
      expect(parsed.part, 'CD1');
      expect(parsed.title, 'Intro');
    });

    test('detects part from filename when flat', () {
      final parsed = chapterNameFromAudioPath(
        '/lib/Author/Book/CD2|03|The Bridge.mp3',
        bookPath: '/lib/Author/Book',
      );
      expect(parsed.part, 'CD2');
      expect(parsed.title, 'The Bridge');
    });

    test('directory part wins over filename part', () {
      final parsed = chapterNameFromAudioPath(
        '/lib/Author/Book/CD1/Parte 9|01 - Intro.mp3',
        bookPath: '/lib/Author/Book',
      );
      expect(parsed.part, 'CD1');
      expect(parsed.title, 'Intro');
    });
  });

  group('bookPartsFromChapters', () {
    test('groups files by part label from paths', () {
      final files = [
        '/b/CD1/a.mp3',
        '/b/CD1/b.mp3',
        '/b/CD2/c.mp3',
      ];
      final chapters = [
        {'part': 'CD1', 'duration': 10.0, 'title': 'A'},
        {'part': 'CD1', 'duration': 5.0, 'title': 'B'},
        {'part': 'CD2', 'duration': 8.0, 'title': 'C'},
      ];
      final parts = bookPartsFromChapters(
        chapters: chapters,
        audioFiles: files,
        bookPath: '/b',
      );
      expect(parts.map((p) => p.name), ['CD1', 'CD2']);
      expect(parts.first.audioFiles.length, 2);
      expect(parts.first.path, '/b/CD1');
      expect(parts.first.order, 1);
      expect(parts.last.order, 2);
    });
  });

  group('chaptersNeedDetection', () {
    test('empty needs detection', () {
      expect(chaptersNeedDetection([]), isTrue);
    });

    test('generic placeholders need detection', () {
      expect(
        chaptersNeedDetection([
          {'title': 'Chapter 1', 'displayTitle': 'Chapter 1'},
          {'title': 'Capítulo 2', 'displayTitle': 'Capítulo 2'},
        ]),
        isTrue,
      );
    });

    test('real titles do not need detection', () {
      expect(
        chaptersNeedDetection([
          {'title': 'The Storm', 'displayTitle': 'The Storm'},
        ]),
        isFalse,
      );
    });
  });
  group('finalizeChapterTitles', () {
    test('strips part name from title and displayTitle', () {
      final out = finalizeChapterTitles(
        [
          {
            'title': 'Part I - Capítulo 1',
            'displayTitle': 'Part I - Capítulo 1',
            'part': 'Part I',
          },
        ],
        exposeParts: true,
      );
      expect(out.single['title'], 'Capítulo 1');
      expect(out.single['displayTitle'], 'Capítulo 1');
      expect(out.single['part'], 'Part I');
    });

    test('drops part when only prologue/epilogue', () {
      final chapters = [
        {'title': 'Capítulo 1', 'displayTitle': 'Capítulo 1', 'part': 'Epilogue'},
        {'title': 'Opening', 'displayTitle': 'Opening', 'part': 'Prologue'},
      ];
      final parts = bookPartsFromChapters(
        chapters: chapters,
        audioFiles: [
          '/b/Epilogue/a.mp3',
          '/b/Prologue/b.mp3',
        ],
        bookPath: '/b',
      );
      expect(parts, isEmpty);
      final out = finalizeChapterTitles(chapters, exposeParts: false);
      expect(out.every((c) => c['part'] == null), isTrue);
    });

    test('title equal to part becomes Chapter 1', () {
      final out = finalizeChapterTitles(
        [
          {
            'title': 'Part IV - The Queen of the Damned',
            'displayTitle': 'Part IV - The Queen of the Damned',
            'part': 'Part IV - The Queen of the Damned',
          },
        ],
        exposeParts: true,
      );
      expect(out.single['title'], 'Chapter 1');
      expect(out.single['part'], 'Part IV - The Queen of the Damned');
    });
  });

  group('relateChaptersToParts', () {
    test('links epilogue and intro chapters to parts when structural parts exist',
        () {
      const book = '/b';
      final audio = [
        '$book/0| Intro.mp3',
        '$book/0| Proem.mp3',
        '$book/1| Part I - Chapter 1 - The Legend.mp3',
        '$book/E| Epilogue - Interview - Chapter 1.mp3',
      ];
      final raw = <Map<String, dynamic>>[];
      for (var i = 0; i < audio.length; i++) {
        final p = chapterNameFromAudioPath(audio[i], bookPath: book);
        raw.add({
          'index': i + 1,
          'title': p.title,
          'displayTitle': p.title,
          if (p.part != null) 'part': p.part,
        });
      }

      final relation = relateChaptersToParts(
        chapters: raw,
        audioFiles: audio,
        bookPath: book,
      );

      expect(relation.parts.map((p) => p.name).toList(), [
        'Intro',
        'Proem',
        'Part I',
        'Epilogue - Interview',
      ]);
      expect(
        relation.chapters.map((c) => c['part']).toList(),
        ['Intro', 'Proem', 'Part I', 'Epilogue - Interview'],
      );
      expect(relation.isConsistent, isTrue);
    });
  });
}
