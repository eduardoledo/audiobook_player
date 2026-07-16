import 'package:get_it/get_it.dart';

import 'services/audiobook_scanner.dart';
import 'services/library_storage.dart';
import 'services/audio_player_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final storage = LibraryStorage();
  getIt.registerSingleton<LibraryStorage>(storage);

  getIt.registerLazySingleton<AudiobookScanner>(() => AudiobookScanner());
  getIt.registerSingleton<AudioPlayerService>(AudioPlayerService());
}
