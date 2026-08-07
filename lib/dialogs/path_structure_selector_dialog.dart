import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/path_pattern_rule.dart';
import '../service_locator.dart';
import '../services/library_storage.dart';

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
    String samplePath = p.normalize(widget.rootPath);

    try {
      final dir = Directory(samplePath);
      if (await dir.exists()) {
        final entities = await dir.list(recursive: true).toList();
        final firstAudio = entities.firstWhere(
          (e) {
            final ext = p.extension(e.path).toLowerCase();
            return ext == '.m4b' || ext == '.mp3' || ext == '.m4a';
          },
          orElse: () => dir,
        );

        if (firstAudio is File) {
          samplePath = p.dirname(firstAudio.path);
        } else {
          // If no audio file found directly or samplePath is root, find first sub-directory with content
          final subDirs = entities.whereType<Directory>().toList();
          if (subDirs.isNotEmpty) {
            // Sort to get deepest or first structured path
            subDirs.sort((a, b) => b.path.length.compareTo(a.path.length));
            samplePath = subDirs.first.path;
          }
        }
      }
    } catch (_) {}

    // Compute full path relative to scan root
    final relativeFromRoot = samplePath.startsWith(root)
        ? (samplePath == root
            ? ''
            : samplePath.substring(root.endsWith(p.separator)
                ? root.length
                : root.length + 1))
        : p.basename(samplePath);

    final segments = p
        .split(relativeFromRoot)
        .where((s) => s.isNotEmpty)
        .toList();

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

    setState(() {
      _resolvedRootPath = root;
      _sampleSegments = segments;
      _selectedRoles = defaultRoles;
      _isLoading = false;
    });
  }

  String _resolvedRootPath = '';

  Future<void> _saveRule() async {
    final rule = PathPatternRule(
      rootPath: _resolvedRootPath.isNotEmpty ? _resolvedRootPath : widget.rootPath,
      roles: _selectedRoles,
    );
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
                    child: Text(
                      relativeDisplayPath.isEmpty ? '(Directorio Raíz)' : relativeDisplayPath,
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
