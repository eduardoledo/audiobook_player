import 'package:metadata_cli/epub_structure.dart';
void main() {
  final e = parseEpubStructure('/home/eduardo/Descargas/Books/Audiobooks/Brandon Sanderson/Cosmere/02 - Mistborn/Era 1/01 - The Final Empire/The Final Empire by Brandon Sanderson.epub');
  for (var i = 0; i < 5 && i < e.entries.length; i++) {
    final x = e.entries[i];
    print('${i+1}. ${x.title} words=${x.wordCount} «${x.firstWords}»');
  }
  print('total=${e.entries.length}');
}
