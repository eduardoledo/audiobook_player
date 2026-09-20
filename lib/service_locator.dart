import 'package:get_it/get_it.dart';

import 'features/player/data/repositories/player_repository_impl.dart';
import 'features/player/domain/repositories/player_repository.dart';
import 'services/audiobook_scanner.dart';
import 'services/library_storage.dart';
import 'services/audio_player_service.dart';
import 'services/google_drive_service.dart';
import 'services/structure_detection_job.dart';
import 'services/structure_detection_notifications.dart';
import 'services/whisper_model_manager.dart';

import 'services/crashlytics_service.dart';

import 'services/web_server_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final storage = LibraryStorage();
  getIt.registerSingleton<LibraryStorage>(storage);

  final crashlytics = CrashlyticsService();
  getIt.registerSingleton<CrashlyticsService>(crashlytics);

  getIt.registerLazySingleton<AudiobookScanner>(() => AudiobookScanner());
  getIt.registerSingleton<AudioPlayerService>(AudioPlayerService());
  getIt.registerLazySingleton<PlayerRepository>(
    () => PlayerRepositoryImpl(
      playerService: getIt<AudioPlayerService>(),
      storage: getIt<LibraryStorage>(),
    ),
  );
  getIt.registerLazySingleton<GoogleDriveService>(() => GoogleDriveService());
  getIt.registerLazySingleton<WhisperModelManager>(() => WhisperModelManager());
  getIt.registerLazySingleton<WebServerService>(() => WebServerService());

  final notifs = StructureDetectionNotifications();
  await notifs.init();
  getIt.registerSingleton<StructureDetectionNotifications>(notifs);
  getIt.registerSingleton<StructureDetectionJob>(
    StructureDetectionJob(
      modelManager: getIt<WhisperModelManager>(),
      notifications: notifs,
    ),
  );
}
