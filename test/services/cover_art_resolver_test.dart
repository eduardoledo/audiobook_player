import 'package:flutter_test/flutter_test.dart';
import 'package:audiobook_player/services/cover_art_resolver.dart';

void main() {
  group('CoverArtResolver Priority Pipeline (Ticket 04)', () {
    test('returns local file source when cover.jpg or cover.png exists', () async {
      final resolver = CoverArtResolver(
        checkFileExists: (path) async => path.endsWith('cover.jpg'),
        checkHasEmbeddedMetadata: (files) async => true,
      );

      final result = await resolver.resolveCoverArt(
        bookDir: '/storage/books/Mistborn',
        audioFiles: ['01.mp3'],
        onRequestOnlineSearch: () async => true,
      );

      expect(result.source, equals(CoverArtSource.localFile));
      expect(result.path, equals('/storage/books/Mistborn/cover.jpg'));
    });

    test('returns embedded metadata source when no local file exists', () async {
      final resolver = CoverArtResolver(
        checkFileExists: (path) async => false,
        checkHasEmbeddedMetadata: (files) async => true,
      );

      final result = await resolver.resolveCoverArt(
        bookDir: '/storage/books/Mistborn',
        audioFiles: ['01.mp3'],
        onRequestOnlineSearch: () async => true,
      );

      expect(result.source, equals(CoverArtSource.embeddedMetadata));
    });

    test('prompts user for online search consent when local/embedded artwork is absent', () async {
      bool userPrompted = false;

      final resolver = CoverArtResolver(
        checkFileExists: (path) async => false,
        checkHasEmbeddedMetadata: (files) async => false,
        fetchOnlineCoverArt: (dir) async => '/cache/covers/fetched.jpg',
      );

      final result = await resolver.resolveCoverArt(
        bookDir: '/storage/books/Mistborn',
        audioFiles: ['01.mp3'],
        onRequestOnlineSearch: () async {
          userPrompted = true;
          return true; // User consents
        },
      );

      expect(userPrompted, isTrue);
      expect(result.source, equals(CoverArtSource.onlineSearch));
      expect(result.path, equals('/cache/covers/fetched.jpg'));
    });

    test('falls back to asset placeholder when user rejects online search prompt', () async {
      final resolver = CoverArtResolver(
        checkFileExists: (path) async => false,
        checkHasEmbeddedMetadata: (files) async => false,
      );

      final result = await resolver.resolveCoverArt(
        bookDir: '/storage/books/Mistborn',
        audioFiles: ['01.mp3'],
        onRequestOnlineSearch: () async => false, // User declines
      );

      expect(result.source, equals(CoverArtSource.placeholderAsset));
    });
  });
}
