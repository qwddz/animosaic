import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/core/json_file_store.dart';
import 'package:puzzles/features/progress/data/progress_controller.dart';
import 'package:puzzles/features/progress/domain/puzzle_progress.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';

void main() {
  group('PuzzleProgress', () {
    test('keeps the hardest completed difficulty', () {
      final progress = const PuzzleProgress()
          .withCompletion('fox', Difficulty.medium)
          .withCompletion('fox', Difficulty.easy);
      expect(progress.bestFor('fox'), Difficulty.medium);
      expect(
        progress.withCompletion('fox', Difficulty.expert).bestFor('fox'),
        Difficulty.expert,
      );
    });

    test('counts completed pictures of a category', () {
      final progress = const PuzzleProgress()
          .withCompletion('a', Difficulty.easy)
          .withCompletion('c', Difficulty.hard);
      expect(progress.completedCount(['a', 'b', 'c']), 2);
      expect(progress.isCompleted('b'), isFalse);
    });

    test('survives JSON; unreadable or newer data gives null', () {
      final progress = const PuzzleProgress().withCompletion(
        'a',
        Difficulty.hard,
      );
      final restored = PuzzleProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())),
      )!;
      expect(restored.bestFor('a'), Difficulty.hard);
      expect(PuzzleProgress.fromJson('junk'), isNull);
      expect(PuzzleProgress.fromJson({'version': 2, 'best': {}}), isNull);
      expect(
        PuzzleProgress.fromJson({
          'version': 1,
          'best': {'a': 'giant', 'b': 'easy'},
        })!.completedCount(['a', 'b']),
        1,
      );
    });
  });

  group('ProgressController', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('progress'));
    tearDown(() => dir.deleteSync(recursive: true));

    File progressFile() => File('${dir.path}/progress.json');

    ProviderContainer newContainer() {
      final container = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWithValue(
            JsonFileStore(() async => dir, 'progress.json'),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<PuzzleProgress> reload() =>
        newContainer().read(progressProvider.future);

    test('saves progress and reloads it after a restart', () async {
      await newContainer()
          .read(progressProvider.notifier)
          .recordCompletion('fox', Difficulty.hard);
      expect((await reload()).bestFor('fox'), Difficulty.hard);
    });

    test('a completion while progress is still loading is kept', () async {
      progressFile().writeAsStringSync(
        jsonEncode({
          'version': 1,
          'best': {'cat': 'easy'},
        }),
      );
      final container = newContainer();
      // No read before: build() is still running when the call arrives.
      await container
          .read(progressProvider.notifier)
          .recordCompletion('fox', Difficulty.medium);
      final saved = await reload();
      expect(saved.bestFor('cat'), Difficulty.easy);
      expect(saved.bestFor('fox'), Difficulty.medium);
    });

    test('two completions in a row are both saved', () async {
      final controller = newContainer().read(progressProvider.notifier);
      await Future.wait([
        controller.recordCompletion('fox', Difficulty.easy),
        controller.recordCompletion('cat', Difficulty.hard),
      ]);
      final saved = await reload();
      expect(saved.bestFor('fox'), Difficulty.easy);
      expect(saved.bestFor('cat'), Difficulty.hard);
    });

    test('an easier completion does not downgrade the saved best', () async {
      final controller = newContainer().read(progressProvider.notifier);
      await controller.recordCompletion('fox', Difficulty.expert);
      await controller.recordCompletion('fox', Difficulty.easy);
      expect((await reload()).bestFor('fox'), Difficulty.expert);
    });

    test('a file from a newer version is never overwritten', () async {
      const newer = '{"version":2,"stars":{"fox":3}}';
      progressFile().writeAsStringSync(newer);
      final container = newContainer();
      await container
          .read(progressProvider.notifier)
          .recordCompletion('cat', Difficulty.easy);
      expect(progressFile().readAsStringSync(), newer);
      // The completion still shows in this run.
      expect(
        container.read(progressProvider).value!.bestFor('cat'),
        Difficulty.easy,
      );
    });
  });
}
