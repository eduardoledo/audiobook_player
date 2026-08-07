import 'package:flutter/material.dart';

import '../models/structure_detection_models.dart';
import '../service_locator.dart';
import '../services/structure_detection_job.dart';
import 'structure_detection_progress_dialog.dart';

/// Persistent chip shown while a structure detection job is active or finished.
class StructureDetectionBanner extends StatelessWidget {
  const StructureDetectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final job = getIt<StructureDetectionJob>();
    return ListenableBuilder(
      listenable: job,
      builder: (context, _) {
        if (!job.hasJob || job.panelOpen) {
          return const SizedBox.shrink();
        }

        final p = job.progress;
        final pct = ((p?.progress ?? 0) * 100).round();
        final status = switch (job.status) {
          StructureDetectionJobStatus.paused => 'Pausado',
          StructureDetectionJobStatus.completed => 'Listo',
          StructureDetectionJobStatus.error => 'Error',
          StructureDetectionJobStatus.running => p?.status ?? 'Detectando',
          StructureDetectionJobStatus.idle => '',
        };
        final markers = job.partialMarkers.length;
        final title = job.book?.title ?? 'Audiolibro';

        return Material(
          color: const Color(0xFF2A2A2A),
          child: InkWell(
            onTap: () {
              job.openPanel();
              showStructureDetectionPanel(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    job.status == StructureDetectionJobStatus.paused
                        ? Icons.pause_circle_outline
                        : job.status == StructureDetectionJobStatus.completed
                            ? Icons.check_circle_outline
                            : Icons.account_tree,
                    color: const Color(0xFFE8B86D),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Estructura · $title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$status · $pct% · $markers marcadores',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (job.status == StructureDetectionJobStatus.running)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: job.pause,
                      icon: const Icon(Icons.pause, color: Colors.white70),
                      tooltip: 'Pausar',
                    )
                  else if (job.status == StructureDetectionJobStatus.paused)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => job.resume(),
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Color(0xFF8FBF9F),
                      ),
                      tooltip: 'Reanudar',
                    ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
