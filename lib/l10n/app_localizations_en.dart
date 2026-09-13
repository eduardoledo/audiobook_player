// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Audiobook Player';

  @override
  String get audiobooks => 'Audiobooks';

  @override
  String get ebooks => 'E-Books';

  @override
  String get playlists => 'Playlists';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get structuresAndLibrary => 'Structures & Library';

  @override
  String get scanFolder => 'Add folder to scan';

  @override
  String get selectFolderTitle => 'Select folder to scan for audiobooks';

  @override
  String get searchPlaceholder => 'Search by title, author, saga...';

  @override
  String get emptyLibrary => 'No audiobooks found';

  @override
  String get emptyLibrarySubtitle => 'Tap the button above to add a folder';

  @override
  String get scanning => 'Scanning library...';

  @override
  String get fetchingMetadata => 'Fetching metadata...';

  @override
  String get playNextTitle => 'Play next audiobook?';

  @override
  String playNextPrompt(String currentBook, String nextBook) {
    return 'You finished \"$currentBook\". Do you want to continue with \"$nextBook\"?';
  }

  @override
  String get backToList => 'Back to library';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get chapters => 'Chapters';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get speed => 'Speed';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get off => 'Off';

  @override
  String get endOfChapter => 'End of chapter';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortSeries => 'Series / Reading Order';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAuthor => 'Author';

  @override
  String get sortRecent => 'Recently Added';

  @override
  String get filterAll => 'All';

  @override
  String get filterInProgress => 'In Progress';

  @override
  String get filterCompleted => 'Completed';
}
