import 'package:get_it/get_it.dart';

import 'services/audiobook_scanner.dart';
import 'services/library_storage.dart';
import 'services/audio_player_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<LibraryStorage>(() => LibraryStorage());
  getIt.registerLazySingleton<AudiobookScanner>(() => AudiobookScanner());
  getIt.registerLazySingleton<AudioPlayerService>(() => AudioPlayerService());
}
