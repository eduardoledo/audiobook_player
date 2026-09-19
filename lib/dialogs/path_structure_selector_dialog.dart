import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/path_pattern_rule.dart';
import '../service_locator.dart';
import '../services/library_storage.dart';
import '../services/path_metadata_parser.dart';

class PathStructureSelectorDialog extends StatefulWidget {
  final String rootPath;
  final VoidCallback? onRuleSaved;

  const PathStructureSelectorDialog({
    super.key,
    required this.rootPath,
    this.onRuleSaved,
  });

  @override
  State<PathStructureSelectorDialog> createState() =>
      _PathStructureSelectorDialogState();
}

class _PathStructureSelectorDialogState
    extends State<PathStructureSelectorDialog> {
  final _storage = getIt<LibraryStorage>();
  List<String> _sampleSegments = [];
  List<PathSegmentRole> _selectedRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    final existingScanPaths = await _storage.getScanPaths();
    
    // Find closest scan root or parent directory
    String matchedRoot = widget.rootPath;
    for (final sp in existingScanPaths) {
      if (widget.rootPath == sp || widget.rootPath.startsWith('$sp${p.separator}')) {
        matchedRoot = sp;
        break;
      }
    }

    final root = p.normalize(matchedRoot);
    final targetSearchPath = p.normalize(widget.rootPath);
    String samplePath = targetSearchPath;

    try {
      // First scan starting from targetSearchPath, or fallback to root if targetSearchPath doesn't exist/has no audio
      Directory dir = Directory(targetSearchPath);
      if (!await dir.exists()) {
        dir = Directory(root);
      }

      if (await dir.exists()) {
        final entities = await dir.list().toList();
        final firstAudio = entities.firstWhere(
          (e) {
            final ext = p.extension(e.path).toLowerCase();
            return ext == '.m4b' || ext == '.mp3' || ext == '.m4a';
          },
          orElse: () => dir,
        );

        if (firstAudio is File) {
          var parentDir = firstAudio.parent;
          if (PathMetadataParser.looksLikeDiscPartFolder(p.basename(parentDir.path))) {
            parentDir = parentDir.parent;
          }
          samplePath = parentDir.path;
        } else {
          final subDirs = entities.whereType<Directory>().toList();
          if (subDirs.isNotEmpty) {
            subDirs.sort((a, b) => b.path.length.compareTo(a.path.length));
            samplePath = subDirs.first.path;
          }
        }
      }
    } catch (_) {}

    // Compute full path relative to scan root
    final relativeFromRoot = p.relative(samplePath, from: root);

    var segments = p
        .split(relativeFromRoot)
        .where((s) => s.isNotEmpty && s != '.')
        .toList();

    if (segments.isEmpty) {
      segments = [p.basename(root)];
    }

    // Check if rule already saved
    final existingRules = await _storage.getPathPatternRules();
    final savedRule = existingRules[root];

    final defaultRoles = <PathSegmentRole>[];
    for (var i = 0; i < segments.length; i++) {
      if (savedRule != null && i < savedRule.roles.length) {
        defaultRoles.add(savedRule.roles[i]);
      } else {
        // Fallback default heuristic: 0 -> author, 1 -> universe/saga, 2 -> saga/title, ...
        if (i == 0) {
          defaultRoles.add(PathSegmentRole.author);
        } else if (i == 1 && segments.length > 3) {
          defaultRoles.add(PathSegmentRole.universe);
        } else if (i == segments.length - 2 && segments.length >= 3) {
          defaultRoles.add(PathSegmentRole.saga);
        } else if (i == segments.length - 1) {
          defaultRoles.add(PathSegmentRole.bookTitle);
        } else {
          defaultRoles.add(PathSegmentRole.ignore);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _resolvedRootPath = root;
      _sampleSegments = segments;
      _selectedRoles = defaultRoles;
      _isLoading = false;
    });
  }

  String _resolvedRootPath = '';

  Future<void> _saveRule() async {
    final targetPath =
        _resolvedRootPath.isNotEmpty ? _resolvedRootPath : widget.rootPath;
    final rule = PathPatternRule(
      rootPath: targetPath,
      roles: _selectedRoles,
    );

    final conflict = await _storage.validatePathPatternConflict(rule);
    if (conflict.hasConflict && mounted) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: const Text(
            'Conflicto de Patrón Detectado',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${conflict.reason}\n\n¿Deseás mantener el patrón anterior o reemplazarlo con el nuevo?',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Mantener Patrón Anterior',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8B86D),
                foregroundColor: const Color(0xFF1A1A1A),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reemplazar con Nuevo Patrón'),
            ),
          ],
        ),
      );

      if (shouldReplace != true) {
        return;
      }
    }

    await _storage.savePathPatternRule(rule);
    widget.onRuleSaved?.call();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final relativeDisplayPath = _sampleSegments.join(' / ');

    return AlertDialog(
      title: const Text('Estructura de la Ruta'),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subruta completa desde el directorio de escaneo:',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE8B86D).withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      relativeDisplayPath.isEmpty ? widget.rootPath : relativeDisplayPath,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE8B86D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Seleccioná la función de cada segmento del path (se aplicará a todas las carpetas dentro de la raíz):',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_sampleSegments.length, (index) {
                    final segment = _sampleSegments[index];
                    final currentRole = _selectedRoles[index];

                    return Card(
                      color: const Color(0xFF2A2A2A),
                      margin: const EdgeInsets.only(bottom: 10.0),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nivel ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE8B86D),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    segment,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<PathSegmentRole>(
                              dropdownColor: const Color(0xFF333333),
                              value: currentRole,
                              onChanged: (newRole) {
                                if (newRole != null) {
                                  setState(() {
                                    _selectedRoles[index] = newRole;
                                  });
                                }
                              },
                              items: PathSegmentRole.values.map((role) {
                                return DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    style: const TextStyle(fontSize: 13, color: Colors.white),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveRule,
          child: const Text('Guardar Patrón'),
        ),
      ],
    );
  }
}
