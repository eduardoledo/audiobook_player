import 'package:flutter/material.dart';

import '../models/detected_marker.dart';

/// Review detected markers before applying as chapters.
class StructureReviewScreen extends StatefulWidget {
  final List<DetectedMarker> markers;
  final String bookTitle;
  final String applyLabel;

  const StructureReviewScreen({
    super.key,
    required this.markers,
    required this.bookTitle,
    this.applyLabel = 'Aplicar',
  });

  @override
  State<StructureReviewScreen> createState() => _StructureReviewScreenState();
}

class _StructureReviewScreenState extends State<StructureReviewScreen> {
  late List<DetectedMarker> _markers;

  @override
  void initState() {
    super.initState();
    _markers = List.from(widget.markers);
  }

  String _typeLabel(MarkerType t) => switch (t) {
        MarkerType.prologue => 'Prólogo',
        MarkerType.part => 'Parte',
        MarkerType.chapter => 'Capítulo',
        MarkerType.epilogue => 'Epílogo',
        MarkerType.end => 'Fin',
      };

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
        title: Text(
          'Revisar: ${widget.bookTitle}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _markers.isEmpty
          ? const Center(
              child: Text(
                'No se detectaron marcadores.\nProbá con otro libro o más narración de capítulos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              itemCount: _markers.length,
              itemBuilder: (context, index) {
                final m = _markers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFFE8B86D).withValues(alpha: 0.2),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFFE8B86D),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    m.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${_typeLabel(m.type)} · ${_formatMs(m.positionMs)}'
                    '${m.rawText.isNotEmpty ? '\n"${m.rawText}"' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  isThreeLine: m.rawText.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      setState(() => _markers.removeAt(index));
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _markers.isEmpty
                      ? null
                      : () => Navigator.pop(context, _markers),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B86D),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(widget.applyLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
