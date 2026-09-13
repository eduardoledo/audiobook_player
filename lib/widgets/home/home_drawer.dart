import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../bloc/home_cubit.dart';
import '../../bloc/home_state.dart';
import '../../dialogs/path_structure_selector_dialog.dart';
import '../../l10n/app_localizations.dart';

class HomeDrawer extends StatelessWidget {
  final HomeState state;

  const HomeDrawer({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleText = l10n?.structuresAndLibrary ?? 'Estructuras y Biblioteca';

    return Drawer(
      backgroundColor: const Color(0xFF252525),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_special, size: 48, color: Color(0xFFE8B86D)),
                const SizedBox(height: 8),
                Text(
                  titleText,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (state.scanPaths.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Carpetas de Biblioteca (${state.scanPaths.length})',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFE8B86D), size: 18),
                  tooltip: 'Re-escanear biblioteca',
                  onPressed: state.isScanning ? null : () => context.read<HomeCubit>().rescanAll(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...state.scanPaths.map((rootPath) {
              final Set<String> allDirectories = {};

              void collectDirectories(String dirPath) {
                allDirectories.add(dirPath);
                final parent = p.dirname(dirPath);
                if (parent != dirPath && parent.startsWith(rootPath) && parent.length >= rootPath.length) {
                  collectDirectories(parent);
                }
              }

              for (final b in state.audiobooks) {
                if (b.path.startsWith(rootPath)) {
                  collectDirectories(b.path);
                }
              }
              for (final eb in state.ebooks) {
                final dir = p.dirname(eb.path);
                if (dir.startsWith(rootPath)) {
                  collectDirectories(dir);
                }
              }

              final subDirs = allDirectories
                  .where((d) => d != rootPath)
                  .toList()
                ..sort();

              return ExpansionTile(
                key: PageStorageKey<String>(rootPath),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                iconColor: const Color(0xFFE8B86D),
                collapsedIconColor: Colors.white60,
                leading: const Icon(Icons.folder_special, color: Color(0xFFE8B86D)),
                title: Text(
                  rootPath,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Directorio Raíz (${subDirs.length} subcarpetas)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_tree, color: Color(0xFFE8B86D), size: 20),
                      tooltip: 'Configurar estructura de la carpeta raíz',
                      onPressed: () async {
                        final homeCubit = context.read<HomeCubit>();
                        final updated = await showDialog<bool>(
                          context: context,
                          builder: (_) => PathStructureSelectorDialog(rootPath: rootPath),
                        );
                        if (updated == true && context.mounted) {
                          unawaited(homeCubit.rescanAll());
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: state.isScanning
                          ? null
                          : () => context.read<HomeCubit>().removePath(rootPath),
                    ),
                  ],
                ),
                children: subDirs.map((subPath) {
                  final relativeDepth = p.split(p.relative(subPath, from: rootPath)).length;
                  final indent = (relativeDepth - 1) * 12.0;

                  return Padding(
                    padding: EdgeInsets.only(left: 12.0 + indent, bottom: 4.0),
                    child: Card(
                      color: const Color(0xFF2A2A2A),
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder, color: Color(0xFFE8B86D), size: 18),
                        title: Text(
                          subPath,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.account_tree, color: Color(0xFFE8B86D), size: 18),
                          tooltip: 'Configurar roles de esta subcarpeta',
                          onPressed: () async {
                            final homeCubit = context.read<HomeCubit>();
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (_) => PathStructureSelectorDialog(rootPath: subPath),
                            );
                            if (updated == true && context.mounted) {
                              unawaited(homeCubit.rescanAll());
                            }
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay carpetas de biblioteca agregadas aún.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
