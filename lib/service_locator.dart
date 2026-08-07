import 'package:get_it/get_it.dart';

import 'services/audiobook_scanner.dart';
import 'services/library_storage.dart';
import 'services/audio_player_service.dart';
import 'services/google_drive_service.dart';
import 'services/structure_detection_job.dart';
import 'services/structure_detection_notifications.dart';
import 'services/whisper_model_manager.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final storage = LibraryStorage();
  getIt.registerSingleton<LibraryStorage>(storage);

  getIt.registerLazySingleton<AudiobookScanner>(() => AudiobookScanner());
  getIt.registerSingleton<AudioPlayerService>(AudioPlayerService());
  getIt.registerLazySingleton<GoogleDriveService>(() => GoogleDriveService());
  getIt.registerLazySingleton<WhisperModelManager>(() => WhisperModelManager());

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
