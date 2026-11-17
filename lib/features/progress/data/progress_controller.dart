import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/json_file_store.dart';
import '../../puzzle/domain/difficulty.dart';
import '../domain/puzzle_progress.dart';

final progressStoreProvider = Provider<JsonFileStore>(
  (ref) => JsonFileStore(getApplicationSupportDirectory, 'progress.json'),
);

/// Completed pictures, loaded from disk and saved on every change.
class ProgressController extends AsyncNotifier<PuzzleProgress> {
  /// False when the file exists but cannot be read (corrupt, or written by a
  /// newer app version). Progress then lives in memory only, so the file is
  /// never overwritten with less than it holds.
  bool _canWrite = true;

  Future<void> _lastWrite = Future.value();

  @override
  Future<PuzzleProgress> build() async {
    final store = ref.read(progressStoreProvider);
    final progress = PuzzleProgress.fromJson(await store.read());
    if (progress != null) return progress;
    _canWrite = !await store.exists();
    return const PuzzleProgress();
  }

  /// Completions run one after another, each on top of the latest state.
  Future<void> recordCompletion(String puzzleId, Difficulty difficulty) =>
      _lastWrite = _lastWrite.then((_) async {
        final current = await future;
        final updated = current.withCompletion(puzzleId, difficulty);
        if (identical(updated, current)) return;
        state = AsyncData(updated);
        if (_canWrite) {
          await ref.read(progressStoreProvider).write(updated.toJson());
        }
      });
}

final progressProvider =
    AsyncNotifierProvider<ProgressController, PuzzleProgress>(
      ProgressController.new,
    );
