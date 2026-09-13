import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Directory containing `libsherpa-onnx-c-api.so` (+ `libonnxruntime.so`).
///
/// Required for CLI / AOT: the package only loads `libsherpa-onnx-c-api.so` from
/// the default name unless [sherpa.initBindings] is given a directory.
Future<String> resolveSherpaNativeLibDir() async {
  final arch = _linuxArchSubdir();
  final candidates = <String>[];

  // 1) Cached copy (works for compiled ~/.local/bin/metadata_cli).
  final cache = p.join(
    Platform.environment['HOME'] ?? Directory.systemTemp.path,
    '.cache',
    'metadata_cli',
    'native',
    'sherpa',
    arch,
  );
  candidates.add(cache);

  // 2) Next to the executable.
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    candidates.add(p.join(exeDir, 'native', 'sherpa', arch));
    candidates.add(exeDir);
  } catch (_) {}

  // 3) package:sherpa_onnx_linux from the active package config.
  final fromPackage = await _fromPackageUri(arch);
  if (fromPackage != null) candidates.add(fromPackage);

  // 4) Pub-cache glob.
  candidates.addAll(_fromPubCache(arch));

  for (final dir in candidates) {
    if (_hasSherpaSo(dir)) return dir;
  }

  // Copy from pub-cache into CLI cache so the next run (and AOT) works.
  final sources = [
    ?fromPackage,
    ..._fromPubCache(arch),
  ];
  for (final src in sources) {
    if (!_hasSherpaSo(src)) continue;
    await _copySherpaLibs(src, cache);
    if (_hasSherpaSo(cache)) return cache;
  }

  throw StateError(
    'Could not find libsherpa-onnx-c-api.so. '
    'Install package sherpa_onnx_linux or place the .so under $cache',
  );
}

String _linuxArchSubdir() {
  final abi = Platform.version; // not ideal
  // Prefer uname.
  try {
    final r = Process.runSync('uname', ['-m']);
    final m = (r.stdout as String).trim();
    if (m == 'aarch64' || m == 'arm64') return 'aarch64';
  } catch (_) {}
  if (abi.contains('arm64') || abi.contains('aarch64')) return 'aarch64';
  return 'x64';
}

bool _hasSherpaSo(String dir) {
  final f = File(p.join(dir, 'libsherpa-onnx-c-api.so'));
  return f.existsSync();
}

Future<String?> _fromPackageUri(String arch) async {
  try {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:sherpa_onnx_linux/README.md'),
    );
    if (uri == null || !uri.isScheme('file')) return null;
    // .../sherpa_onnx_linux-x.y.z/lib/README.md → ../linux/<arch>
    final libFolder = p.dirname(uri.toFilePath());
    final root = p.dirname(libFolder);
    final dir = p.join(root, 'linux', arch);
    if (_hasSherpaSo(dir)) return dir;
  } catch (_) {}
  return null;
}

List<String> _fromPubCache(String arch) {
  final home = Platform.environment['HOME'];
  if (home == null) return const [];
  final hosted = Directory(p.join(home, '.pub-cache', 'hosted'));
  if (!hosted.existsSync()) return const [];
  final out = <String>[];
  try {
    for (final host in hosted.listSync().whereType<Directory>()) {
      for (final pkg in host.listSync().whereType<Directory>()) {
        final name = p.basename(pkg.path);
        if (!name.startsWith('sherpa_onnx_linux-')) continue;
        final dir = p.join(pkg.path, 'linux', arch);
        if (_hasSherpaSo(dir)) out.add(dir);
      }
    }
  } catch (_) {}
  // Prefer higher versions last → reverse sort by path.
  out.sort();
  return out.reversed.toList();
}

Future<void> _copySherpaLibs(String srcDir, String destDir) async {
  await Directory(destDir).create(recursive: true);
  for (final name in [
    'libsherpa-onnx-c-api.so',
    'libsherpa-onnx-cxx-api.so',
    'libonnxruntime.so',
  ]) {
    final src = File(p.join(srcDir, name));
    if (!await src.exists()) continue;
    await src.copy(p.join(destDir, name));
  }
}
