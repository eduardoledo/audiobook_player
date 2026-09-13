import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../../l10n/app_localizations.dart';

class SleepTimerSheet extends StatelessWidget {
  final AudioPlayerService playerService;

  const SleepTimerSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, AudioPlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252525),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SleepTimerSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.sleepTimer ?? 'Sleep Timer';
    final offLabel = l10n?.off ?? 'Off';
    final endOfChapterLabel = l10n?.endOfChapter ?? 'End of chapter';

    return SafeArea(
      child: ValueListenableBuilder<Duration?>(
        valueListenable: playerService.sleepTimeRemaining,
        builder: (context, remaining, _) {
          return Padding(
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
                if (remaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFFE8B86D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildOption(
                  context: context,
                  label: offLabel,
                  isSelected: !playerService.isSleepTimerActive,
                  onTap: () {
                    playerService.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
                for (final minutes in [5, 15, 30, 45, 60])
                  _buildOption(
                    context: context,
                    label: '$minutes minutes',
                    isSelected: remaining != null && (remaining.inMinutes == minutes || (remaining.inMinutes == minutes - 1 && remaining.inSeconds % 60 > 50)),
                    onTap: () {
                      playerService.setSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(context);
                    },
                  ),
                _buildOption(
                  context: context,
                  label: endOfChapterLabel,
                  isSelected: playerService.sleepAtChapterEnd,
                  onTap: () {
                    playerService.setSleepAtChapterEnd();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFE8B86D) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFFE8B86D))
          : null,
      onTap: onTap,
    );
  }
}
