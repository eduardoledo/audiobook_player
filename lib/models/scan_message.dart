import 'audiobook.dart';
import 'ebook.dart';

class ScanMessage {
  final Audiobook? audiobook;
  final Ebook? ebook;
  final double? progress;
  final bool isDone;

  const ScanMessage({
    this.audiobook,
    this.ebook,
    this.progress,
    this.isDone = false,
  });
}
