import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_cubit.dart';
import '../models/detected_marker.dart';
import '../models/structure_detection_models.dart';
import '../screens/structure_review_screen.dart';
import '../service_locator.dart';
import '../services/structure_detection_job.dart';

/// Shows or reopens the structure detection progress panel.
Future<void> showStructureDetectionPanel(BuildContext context) {
  final cubit = context.read<HomeCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF252525),
    barrierColor: Colors.black54,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => BlocProvider.value(
      value: cubit,
      child: const StructureDetectionPanel(),
    ),
  );
}

class StructureDetectionPanel extends StatefulWidget {
  const StructureDetectionPanel({super.key});

  @override
  State<StructureDetectionPanel> createState() =>
      _StructureDetectionPanelState();
}

class _StructureDetectionPanelState extends State<StructureDetectionPanel> {
  static const _etaMinProgress = 0.03;
  static const _etaEmaAlpha = 0.25;

  late final StructureDetectionJob _job;
  Duration? _smoothedEtaTotal;
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _job = getIt<StructureDetectionJob>();
    _job.openPanel();
    _job.addListener(_onJob);
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _job.removeListener(_onJob);
    super.dispose();
  }

  void _onJob() {
    if (!mounted) return;
    setState(() => _updateEtaEstimate());
  }

  void _updateEtaEstimate() {
    final startedAt = _job.startedAt;
    final progress = _job.progress?.progress;
    if (startedAt == null || progress == null || progress < _etaMinProgress) {
      return;
    }
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inMilliseconds <= 0) return;
    final rawTotal = Duration(
      milliseconds: (elapsed.inMilliseconds / progress).round(),
    );
    final previous = _smoothedEtaTotal;
    if (previous == null) {
      _smoothedEtaTotal = rawTotal;
      return;
    }
    final blendedMs = previous.inMilliseconds * (1 - _etaEmaAlpha) +
        rawTotal.inMilliseconds * _etaEmaAlpha;
    _smoothedEtaTotal = Duration(milliseconds: blendedMs.round());
  }

  Duration get _elapsed {
    final startedAt = _job.startedAt;
    if (startedAt == null) return Duration.zero;
    return DateTime.now().difference(startedAt);
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _timingLabel() {
    final elapsedText = _formatDuration(_elapsed);
    final progress = _job.progress?.progress;
    final estimate = _smoothedEtaTotal;
    if (estimate != null &&
        progress != null &&
        progress >= _etaMinProgress) {
      return '$elapsedText / ~${_formatDuration(estimate)}';
    }
    return '$elapsedText / —';
  }

  String _pct(double? value) {
    if (value == null) return '…';
    return '${(value.clamp(0.0, 1.0) * 100).round()}%';
  }

  String _formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _applyPartial({required bool finishAfter}) async {
    final markers = List<DetectedMarker>.from(_job.partialMarkers);
    if (markers.isEmpty) return;

    if (_job.isActive) {
      _job.pause();
    }

    final reviewed = await Navigator.of(context).push<List<DetectedMarker>>(
      MaterialPageRoute(
        builder: (_) => StructureReviewScreen(
          markers: markers,
          bookTitle: _job.book?.title ?? '',
          applyLabel: finishAfter ? 'Aplicar' : 'Aplicar y seguir',
        ),
      ),
    );

    if (!mounted || reviewed == null) return;

    final chapters = await _job.markersToChapters(reviewed);
    if (!mounted) return;
    final book = _job.book;
    if (book == null) return;

    await context.read<HomeCubit>().applyDetectedChapters(book, chapters);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          finishAfter
              ? 'Estructura aplicada: ${chapters.length} capítulos'
              : 'Parcial aplicado (${chapters.length}). Podés reanudar la detección.',
        ),
        backgroundColor: const Color(0xFF333333),
      ),
    );

    if (finishAfter) {
      _job.clear();
      Navigator.of(context).pop();
    }
  }

  Future<void> _onCancel() async {
    await _job.cancel(reset: true);
    if (mounted) Navigator.of(context).pop();
  }

  void _onBackground() {
    _job.minimize();
    Navigator.of(context).pop();
  }

  Widget _progressSection({
    required String label,
    required double? value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _pct(value),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: const Color(0xFF333333),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _job.progress;
    final status = p?.status ??
        switch (_job.status) {
          StructureDetectionJobStatus.paused => 'Pausado',
          StructureDetectionJobStatus.completed => 'Listo',
          StructureDetectionJobStatus.error => 'Error',
          StructureDetectionJobStatus.running => 'Detectando…',
          StructureDetectionJobStatus.idle => 'Inactivo',
        };
    final detail = _job.error != null
        ? _job.error.toString()
        : (p?.detail ?? 'Preparando la detección…');
    final markers = _job.partialMarkers;
    final isPaused = _job.status == StructureDetectionJobStatus.paused;
    final isRunning = _job.status == StructureDetectionJobStatus.running;
    final isDone = _job.status == StructureDetectionJobStatus.completed;
    final isError = _job.status == StructureDetectionJobStatus.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detectando estructura',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_job.book != null)
                  Flexible(
                    child: Text(
                      _job.book!.title,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                color: isError ? Colors.redAccent : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: TextStyle(
                color: isError
                    ? Colors.redAccent.withValues(alpha: 0.85)
                    : Colors.white60,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (!isError) ...[
              const SizedBox(height: 12),
              Text(
                _timingLabel(),
                style: const TextStyle(
                  color: Color(0xFFE8B86D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 16),
              _progressSection(
                label: p?.phaseLabel ?? 'Tarea',
                value: p?.phaseProgress,
                color: const Color(0xFFE8B86D),
              ),
              const SizedBox(height: 16),
              _progressSection(
                label: 'Progreso total',
                value: p?.progress,
                color: const Color(0xFF8FBF9F),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Resultados parciales (${markers.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: markers.isEmpty
                  ? const Text(
                      'Todavía no hay marcadores.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: markers.length,
                      itemBuilder: (context, index) {
                        final m = markers[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            m.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Text(
                            _formatMs(m.positionMs),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isRunning)
                  OutlinedButton.icon(
                    onPressed: _job.pause,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pausar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8B86D),
                      side: const BorderSide(color: Color(0xFFE8B86D)),
                    ),
                  ),
                if (isPaused)
                  OutlinedButton.icon(
                    onPressed: () => _job.resume(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Reanudar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8FBF9F),
                      side: const BorderSide(color: Color(0xFF8FBF9F)),
                    ),
                  ),
                if (_job.isActive || isDone)
                  OutlinedButton.icon(
                    onPressed: _onBackground,
                    icon: const Icon(Icons.minimize, size: 18),
                    label: const Text('Segundo plano'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                if (markers.isNotEmpty && (_job.isActive || isPaused))
                  ElevatedButton.icon(
                    onPressed: () => _applyPartial(finishAfter: false),
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: const Text('Aplicar parcial'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8B86D),
                      foregroundColor: Colors.black,
                    ),
                  ),
                if (isDone)
                  ElevatedButton.icon(
                    onPressed: () => _applyPartial(finishAfter: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Revisar y aplicar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8B86D),
                      foregroundColor: Colors.black,
                    ),
                  ),
                if (_job.isActive || isError)
                  TextButton(
                    onPressed: _onCancel,
                    child: Text(
                      isError ? 'Cerrar' : 'Cancelar',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (isDone)
                  TextButton(
                    onPressed: () {
                      _job.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Descartar',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
