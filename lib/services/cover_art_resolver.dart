import 'dart:io';
import 'package:path/path.dart' as p;

enum CoverArtSource {
  localFile,
  embeddedMetadata,
  onlineSearch,
  placeholderAsset,
}

class CoverArtResult {
  final CoverArtSource source;
  final String? path;

  const CoverArtResult({required this.source, this.path});
}

typedef FileExistsChecker = Future<bool> Function(String path);
typedef EmbeddedMetadataChecker = Future<bool> Function(List<String> audioFiles);
typedef OnlineCoverFetcher = Future<String?> Function(String bookDir);

/// Domain service enforcing strict resolution order for Audiobook cover artwork.
class CoverArtResolver {
  final FileExistsChecker checkFileExists;
  final EmbeddedMetadataChecker checkHasEmbeddedMetadata;
  final OnlineCoverFetcher? fetchOnlineCoverArt;

  CoverArtResolver({
    FileExistsChecker? checkFileExists,
    EmbeddedMetadataChecker? checkHasEmbeddedMetadata,
    this.fetchOnlineCoverArt,
  })  : checkFileExists = checkFileExists ?? ((path) => File(path).exists()),
        checkHasEmbeddedMetadata = checkHasEmbeddedMetadata ?? ((files) async => false);

  Future<CoverArtResult> resolveCoverArt({
    required String bookDir,
    required List<String> audioFiles,
    required Future<bool> Function() onRequestOnlineSearch,
  }) async {
    // 1. Check local file (cover.jpg / cover.png)
    final jpgPath = p.join(bookDir, 'cover.jpg');
    final pngPath = p.join(bookDir, 'cover.png');

    if (await checkFileExists(jpgPath)) {
      return CoverArtResult(source: CoverArtSource.localFile, path: jpgPath);
    }
    if (await checkFileExists(pngPath)) {
      return CoverArtResult(source: CoverArtSource.localFile, path: pngPath);
    }

    // 2. Check embedded audio metadata artwork
    if (await checkHasEmbeddedMetadata(audioFiles)) {
      return const CoverArtResult(source: CoverArtSource.embeddedMetadata);
    }

    // 3. User prompt gate for online search fallback
    final userConsented = await onRequestOnlineSearch();
    if (userConsented && fetchOnlineCoverArt != null) {
      final fetchedPath = await fetchOnlineCoverArt!(bookDir);
      if (fetchedPath != null) {
        return CoverArtResult(source: CoverArtSource.onlineSearch, path: fetchedPath);
      }
    }

    // 4. Fallback to placeholder asset
    return const CoverArtResult(source: CoverArtSource.placeholderAsset);
  }
}
