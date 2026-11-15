import 'package:flutter/material.dart';

import '../models/structure_detection_models.dart';
import '../service_locator.dart';
import '../services/structure_detection_job.dart';
import 'structure_detection_progress_dialog.dart';

/// Persistent chip shown while a structure detection job is active or finished.
class StructureDetectionBanner extends StatelessWidget {
  final StructureDetectionJob? job;

  const StructureDetectionBanner({super.key, this.job});

  @override
  Widget build(BuildContext context) {
    final resolvedJob = job ??
        (getIt.isRegistered<StructureDetectionJob>()
            ? getIt<StructureDetectionJob>()
            : null);
    if (resolvedJob == null) {
      return const SizedBox.shrink();
    }
    final jobInstance = resolvedJob;
    return ListenableBuilder(
      listenable: jobInstance,
      builder: (context, _) {
        if (!jobInstance.hasJob || jobInstance.panelOpen) {
          return const SizedBox.shrink();
        }

        final p = jobInstance.progress;
        final pct = ((p?.progress ?? 0) * 100).round();
        final status = switch (jobInstance.status) {
          StructureDetectionJobStatus.paused => 'Pausado',
          StructureDetectionJobStatus.completed => 'Listo',
          StructureDetectionJobStatus.error => 'Error',
          StructureDetectionJobStatus.running => p?.status ?? 'Detectando',
          StructureDetectionJobStatus.idle => '',
        };
        final markers = jobInstance.partialMarkers.length;
        final title = jobInstance.book?.title ?? 'Audiolibro';

        return Material(
          color: const Color(0xFF2A2A2A),
          child: InkWell(
            onTap: () {
              jobInstance.openPanel();
              showStructureDetectionPanel(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    jobInstance.status == StructureDetectionJobStatus.paused
                        ? Icons.pause_circle_outline
                        : jobInstance.status == StructureDetectionJobStatus.completed
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
                  if (jobInstance.status == StructureDetectionJobStatus.running)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: jobInstance.pause,
                      icon: const Icon(Icons.pause, color: Colors.white70),
                      tooltip: 'Pausar',
                    )
                  else if (jobInstance.status == StructureDetectionJobStatus.paused)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => jobInstance.resume(),
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
