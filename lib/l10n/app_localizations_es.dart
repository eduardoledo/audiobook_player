// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Reproductor de Audiolibros';

  @override
  String get audiobooks => 'Audiolibros';

  @override
  String get ebooks => 'Libros electrónicos';

  @override
  String get playlists => 'Listas de reproducción';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get structuresAndLibrary => 'Estructuras y Biblioteca';

  @override
  String get scanFolder => 'Agregar carpeta para escanear';

  @override
  String get selectFolderTitle =>
      'Seleccionar carpeta para escanear audiolibros';

  @override
  String get searchPlaceholder => 'Buscar por título, autor, saga...';

  @override
  String get emptyLibrary => 'No se encontraron audiolibros';

  @override
  String get emptyLibrarySubtitle =>
      'Toca el botón arriba para agregar una carpeta';

  @override
  String get scanning => 'Escaneando biblioteca...';

  @override
  String get fetchingMetadata => 'Obteniendo metadatos...';

  @override
  String get playNextTitle => '¿Reproducir el siguiente?';

  @override
  String playNextPrompt(String currentBook, String nextBook) {
    return 'Terminaste «$currentBook». ¿Querés seguir con «$nextBook»?';
  }

  @override
  String get backToList => 'Volver al listado';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get chapters => 'Capítulos';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get speed => 'Velocidad';

  @override
  String get sleepTimer => 'Temporizador de apagado';

  @override
  String get off => 'Desactivado';

  @override
  String get endOfChapter => 'Fin del capítulo';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortSeries => 'Saga / Orden de lectura';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortAuthor => 'Autor';

  @override
  String get sortRecent => 'Recientemente agregado';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterInProgress => 'En progreso';

  @override
  String get filterCompleted => 'Completados';
}
