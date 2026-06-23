import 'audiobook.dart';

class ScanMessage {
  final Audiobook? audiobook;
  final double? progress;
  final bool isDone;

  const ScanMessage({
    this.audiobook,
    this.progress,
    this.isDone = false,
  });
}
