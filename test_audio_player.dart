import 'package:just_audio/just_audio.dart';
void main() async {
  final player = AudioPlayer();
  await player.setAudioSources([], initialIndex: 0, initialPosition: Duration.zero);
}
