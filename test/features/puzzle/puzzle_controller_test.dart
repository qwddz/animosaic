import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/core/json_file_store.dart';
import 'package:puzzles/features/audio/audio_controller.dart';
import 'package:puzzles/features/progress/data/progress_controller.dart';
import 'package:puzzles/features/puzzle/data/first_puzzle_store.dart';
import 'package:puzzles/features/puzzle/data/session_repository.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_board.dart';
import 'package:puzzles/features/puzzle/puzzle_controller.dart';
import 'package:puzzles/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SessionRepository repository;
  late ProviderContainer container;
  late FakeAudioBackend audio;
  const args = (puzzleId: 'farm_pig', difficulty: Difficulty.easy);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('puzzle_controller');
    repository = SessionRepository(() async => dir);
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    audio = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioBackendProvider.overrideWithValue(audio),
        sessionRepositoryProvider.overrideWithValue(repository),
        progressStoreProvider.overrideWithValue(
          JsonFileStore(() async => dir, 'progress.json'),
        ),
      ],
    );
  });
  tearDown(() async {
    // Completions are recorded in the background, one after another;
    // queuing one more waits for the earlier ones before disposing.
    await container
        .read(progressProvider.notifier)
        .recordCompletion('farm_pig', Difficulty.easy);
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<PuzzleState> load() async {
    final provider = puzzleControllerProvider(args);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('saves progress after a drop and resumes it next time', () async {
    final state = await load();
    state.session.place(0);
    container
        .read(puzzleControllerProvider(args).notifier)
        .pieceDropped(DropResult.placed);
    final saved = await repository.load('farm_pig', Difficulty.easy);
    expect(saved?.placedCount, 1);
    expect(saved?.seed, state.session.seed);
  });

  test('reports completion at once and clears the save', () async {
    final state = await load();
    final controller = container.read(puzzleControllerProvider(args).notifier);
    state.session.place(0);
    controller.pieceDropped(DropResult.placed);
    for (var i = 1; i < 6; i++) {
      state.session.place(i);
    }
    controller.pieceDropped(DropResult.placed);
    expect(
      container.read(puzzleControllerProvider(args)).value!.completed,
      isTrue,
    );
    // The star is written first, then the save is dropped.
    for (var i = 0; i < 100; i++) {
      if (await repository.load('farm_pig', Difficulty.easy) == null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await repository.load('farm_pig', Difficulty.easy), isNull);
    final progress = await container.read(progressProvider.future);
    expect(progress.bestFor('farm_pig'), Difficulty.easy);
  });

  test('play again starts a fresh session with the same picture', () async {
    final first = await load();
    for (var i = 0; i < 6; i++) {
      first.session.place(i);
    }
    final controller = container.read(puzzleControllerProvider(args).notifier)
      ..pieceDropped(DropResult.placed)
      ..playAgain();
    final next = container.read(puzzleControllerProvider(args)).value!;
    expect(next.completed, isFalse);
    expect(identical(next.session, first.session), isFalse);
    expect(next.session.placedCount, 0);
    expect(identical(next.setup.image, first.setup.image), isTrue);
    expect(controller.args, args);
  });

  test('sounds: pick, snap, and the win fanfare once per completion', () async {
    final state = await load();
    final controller = container.read(puzzleControllerProvider(args).notifier)
      ..piecePicked();
    state.session.place(0);
    controller
      ..pieceDropped(DropResult.placed)
      ..pieceDropped(DropResult.loose)
      ..pieceDropped(DropResult.none);
    for (var i = 1; i < 6; i++) {
      state.session.place(i);
    }
    controller
      ..pieceDropped(DropResult.placed)
      ..pieceDropped(DropResult.placed);
    expect(audio.effects, [Sfx.pick, Sfx.place, Sfx.win]);

    controller.playAgain();
    final next = container.read(puzzleControllerProvider(args)).value!;
    for (var i = 0; i < 6; i++) {
      next.session.place(i);
    }
    controller.pieceDropped(DropResult.placed);
    expect(audio.effects, [Sfx.pick, Sfx.place, Sfx.win, Sfx.win]);
  });

  test('first placed piece ends the first puzzle and stores it', () async {
    final state = await load();
    expect(state.firstPuzzle, isTrue);
    final controller = container.read(puzzleControllerProvider(args).notifier)
      ..pieceDropped(DropResult.loose);
    expect(
      container.read(puzzleControllerProvider(args)).value!.firstPuzzle,
      isTrue,
    );
    state.session.place(0);
    controller.pieceDropped(DropResult.placed);
    final next = container.read(puzzleControllerProvider(args)).value!;
    expect(next.firstPuzzle, isFalse);
    expect(identical(next.session, state.session), isTrue);
    expect(container.read(firstPuzzleStoreProvider).isDone(false), isTrue);
  });

  test('a child with progress is not in the first puzzle', () async {
    await container
        .read(progressProvider.notifier)
        .recordCompletion('farm_cow', Difficulty.easy);
    final state = await load();
    expect(state.firstPuzzle, isFalse);
  });
}
