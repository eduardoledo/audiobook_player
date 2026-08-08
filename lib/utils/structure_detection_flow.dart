import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import '../service_locator.dart';
import '../services/structure_detection_job.dart';
import '../widgets/structure_detection_progress_dialog.dart';

/// Starts or reopens on-device structure detection without pausing playback.
Future<void> runStructureDetectionFlow(
  BuildContext context,
  Audiobook book,
) async {
  final job = getIt<StructureDetectionJob>();

  if (job.isActive && job.book?.path == book.path) {
    if (!job.panelOpen && context.mounted) {
      await showStructureDetectionPanel(context);
    }
    return;
  }

  if (job.hasJob && job.book?.path != book.path) {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Detección en curso',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Hay una detección activa para «${job.book?.title ?? 'otro libro'}». '
          '¿Qué querés hacer?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'open'),
            child: const Text(
              'Ver actual',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              'Cancelar y empezar',
              style: TextStyle(color: Color(0xFFE8B86D)),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'open') {
      await showStructureDetectionPanel(context);
      return;
    }
    if (action != 'cancel') return;
    await job.cancel(reset: true);
  }

  final hasRealChapters = book.chapters.any(
    (c) =>
        !RegExp(r'^Chapter\s+\d+$', caseSensitive: false)
            .hasMatch(c.displayTitle) &&
        c.duration > 0,
  );

  if (hasRealChapters && context.mounted) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          '¿Reemplazar capítulos?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Este libro ya tiene capítulos. Podés aplicar resultados parciales '
          'durante la detección; cada aplicación reemplaza la estructura actual.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continuar',
              style: TextStyle(color: Color(0xFFE8B86D)),
            ),
          ),
        ],
      ),
    );
    if (proceed != true) return;
  }

  if (!context.mounted) return;

  final language = await _pickNarrationLanguage(context);
  if (language == null || !context.mounted) return;

  await job.start(book, language: language);
  if (!context.mounted) return;
  await showStructureDetectionPanel(context);
}

/// Returns Whisper language code: `es`, `en`, or `''` (auto). Null = cancelled.
Future<String?> _pickNarrationLanguage(BuildContext context) async {
  var selected = 'es';
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF252525),
            title: const Text(
              'Idioma de la narración',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Whisper usa este idioma al transcribir ventanas. '
                  'Elegí el de la narración para acelerar y mejorar precisión.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _LanguageRadioGroup(
                  selected: selected,
                  onChanged: (v) => setState(() => selected = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  selected == 'auto' ? '' : selected,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(color: Color(0xFFE8B86D)),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _LanguageRadioGroup extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _LanguageRadioGroup({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label, String subtitle) {
      return RadioListTile<String>(
        value: value,
        activeColor: const Color(0xFFE8B86D),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
    }

    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: [
          tile('es', 'Español', 'Optimizado para palabras clave en español'),
          tile('en', 'Inglés', 'Optimizado para palabras clave en inglés'),
          tile('auto', 'Auto-detectar', 'Selecciona según idioma detectado/archivos'),
        ],
      ),
    );
  }
}
