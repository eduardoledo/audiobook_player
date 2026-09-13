import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../../l10n/app_localizations.dart';

class PlaybackSpeedSheet extends StatelessWidget {
  final AudioPlayerService playerService;

  const PlaybackSpeedSheet({super.key, required this.playerService});

  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static Future<void> show(BuildContext context, AudioPlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252525),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlaybackSpeedSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.speed ?? 'Speed';
    final currentSpeed = playerService.speed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            for (final speed in speeds)
              ListTile(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: (currentSpeed - speed).abs() < 0.05
                        ? const Color(0xFFE8B86D)
                        : Colors.white,
                    fontWeight: (currentSpeed - speed).abs() < 0.05
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: (currentSpeed - speed).abs() < 0.05
                    ? const Icon(Icons.check, color: Color(0xFFE8B86D))
                    : null,
                onTap: () {
                  playerService.setSpeed(speed);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
