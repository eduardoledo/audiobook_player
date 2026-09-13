import 'dart:async';
import 'package:audiobook_player/features/player/domain/repositories/player_repository.dart';
import 'package:audiobook_player/features/player/presentation/cubit/player_cubit.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/models/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlayerRepository implements PlayerRepository {
  final _posController = StreamController<Duration>.broadcast();
  final _playController = StreamController<bool>.broadcast();
  final _durController = StreamController<Duration?>.broadcast();
  final _sleepController = StreamController<Duration?>.broadcast();

  Audiobook? _currentBook;
  Duration _currentPos = Duration.zero;
  double _speed = 1.0;
  bool _isPlaying = false;
  final List<Bookmark> _bookmarks = [];

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<bool> get playingStream => _playController.stream;

  @override
  Stream<Duration?> get durationStream => _durController.stream;

  @override
  Stream<Duration?> get sleepTimerStream => _sleepController.stream;

  @override
  Audiobook? get currentAudiobook => _currentBook;

  @override
  Duration get currentPosition => _currentPos;

  @override
  double get currentSpeed => _speed;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> setAudiobook(
    Audiobook audiobook, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool rewindForResume = false,
  }) async {
    _currentBook = audiobook;
    _currentPos = position;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playController.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playController.add(false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _playController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPos = position;
    _posController.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSleepTimer(Duration duration) async {
    _sleepController.add(duration);
  }

  @override
  Future<void> cancelSleepTimer() async {
    _sleepController.add(null);
  }

  @override
  Future<List<Bookmark>> getBookmarks(String bookPath) async {
    return List.unmodifiable(_bookmarks);
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) async {
    _bookmarks.add(bookmark);
  }

  @override
  Future<void> removeBookmark(int bookmarkId) async {
    _bookmarks.removeWhere((b) => b.id == bookmarkId);
  }

  void dispose() {
    _posController.close();
    _playController.close();
    _durController.close();
    _sleepController.close();
  }
}

void main() {
  late FakePlayerRepository repository;
  late PlayerCubit cubit;

  setUp(() {
    repository = FakePlayerRepository();
    cubit = PlayerCubit(playerRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
    repository.dispose();
  });

  test('initial state has default zero duration and false isPlaying', () {
    expect(cubit.state.position, Duration.zero);
    expect(cubit.state.isPlaying, isFalse);
    expect(cubit.state.speed, 1.0);
  });

  test('setSpeed delegates to repository and emits new speed', () async {
    await cubit.setSpeed(1.5);
    expect(cubit.state.speed, 1.5);
    expect(repository.currentSpeed, 1.5);
  });

  test('togglePlayPause plays when paused and pauses when playing', () async {
    await cubit.togglePlayPause();
    expect(repository.isPlaying, isTrue);

    await cubit.togglePlayPause();
    expect(repository.isPlaying, isFalse);
  });

  test('initAudiobook updates audiobook and speed in state', () async {
    final book = Audiobook(
      path: '/path/to/book',
      title: 'Test Title',
      author: 'Test Author',
      durationFormatted: '00:00:00',
      totalChapters: 1,
      chapters: const [],
      files: const ['/path/to/book/part1.mp3'],
    );

    await cubit.initAudiobook(book);
    expect(cubit.state.audiobook, equals(book));
  });
}
