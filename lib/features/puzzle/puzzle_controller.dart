import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_controller.dart';
import '../catalog/data/manifest_provider.dart';
import '../catalog/domain/content_manifest.dart';
import '../content/data/manifest_source.dart';
import '../content/data/picture_store.dart';
import '../progress/data/progress_controller.dart';
import '../purchase/data/purchase_providers.dart';
import 'data/first_puzzle_store.dart';
import 'data/puzzle_setup.dart';
import 'data/session_repository.dart';
import 'domain/difficulty.dart';
import 'domain/puzzle_board.dart';
import 'domain/puzzle_session.dart';

typedef PuzzleArgs = ({String puzzleId, Difficulty difficulty});

/// The picture is paid and the full version is not unlocked.
class PuzzleLockedException implements Exception {
  const PuzzleLockedException(this.puzzleId);

  final String puzzleId;

  @override
  String toString() => 'PuzzleLockedException: $puzzleId';
}

class PuzzleState {
  const PuzzleState({
    required this.setup,
    this.completed = false,
    this.firstPuzzle = false,
  });

  final PuzzleSetup setup;
  final bool completed;

  /// The child has never placed a piece: the hand hint shows at once.
  final bool firstPuzzle;

  PuzzleSession get session => setup.session;
}

/// Owns one puzzle in progress: loading, saving, completion and restart.
class PuzzleController extends AsyncNotifier<PuzzleState> {
  PuzzleController(this.args);

  final PuzzleArgs args;

  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  @override
  Future<PuzzleState> build() async {
    // Everything is read before the first await. Read, not watch: a
    // manifest refresh must not rebuild a puzzle in play and dispose the
    // picture its game is drawing.
    final manifestFuture = ref.read(manifestProvider.future);
    // Listened, not read: an unlistened stream provider is paused and
    // would never deliver its first value.
    final fullAccessFuture = ref
        .listen(fullAccessProvider.future, (_, _) {})
        .read();
    // Unreadable progress counts as none.
    final hasProgressFuture = ref
        .read(progressProvider.future)
        .then((p) => !p.isEmpty, onError: (_) => false);
    final firstPuzzleStore = ref.read(firstPuzzleStoreProvider);
    final repository = _repository;
    final pictures = ref.read(pictureStoreProvider);
    final progress = ref.read(
      pictureDownloadProgressProvider(args.puzzleId).notifier,
    );
    final manifest = await manifestFuture;
    final entry = manifest.puzzleById(args.puzzleId);
    if (entry != null && !canPlay(entry, fullAccess: await fullAccessFuture)) {
      throw PuzzleLockedException(args.puzzleId);
    }
    final PuzzleSetup setup;
    try {
      setup = await loadPuzzleSetup(
        manifest: manifest,
        repository: repository,
        pictures: pictures,
        puzzleId: args.puzzleId,
        difficulty: args.difficulty,
        onProgress: progress.report,
      );
    } finally {
      progress.report(null);
    }
    final firstPuzzle = !firstPuzzleStore.isDone(await hasProgressFuture);
    if (!ref.mounted) {
      setup.image.dispose();
      return PuzzleState(setup: setup);
    }
    ref.onDispose(setup.image.dispose);
    return PuzzleState(setup: setup, firstPuzzle: firstPuzzle);
  }

  /// Loads again after an error. A picture the CDN refused may have moved
  /// in a newer manifest, so that one is fetched first.
  Future<void> retry() async {
    if (state.error case PictureLoadException(
      failure: PictureLoadFailure.unavailable,
    )) {
      state = const AsyncLoading();
      ref.invalidate(remoteManifestProvider);
      // A failed fetch leaves the current manifest; the reload reports.
      await ref.read(remoteManifestProvider.future).catchError((_) => null);
      if (!ref.mounted) return;
    }
    ref.invalidateSelf();
  }

  void piecePicked() => ref.read(audioControllerProvider).play(Sfx.pick);

  /// Called by the game after every drop. Completion is reported at once,
  /// even if the player leaves before the win overlay shows up.
  void pieceDropped(DropResult result) {
    var current = state.value;
    if (current == null || result == DropResult.none) return;
    if (current.completed) return;
    if (result == DropResult.placed && current.firstPuzzle) {
      unawaited(ref.read(firstPuzzleStoreProvider).markDone());
      current = PuzzleState(setup: current.setup);
      state = AsyncData(current);
    }
    final audio = ref.read(audioControllerProvider);
    if (current.session.isComplete) {
      // The fanfare replaces the snap sound of the last piece.
      audio.play(Sfx.win);
      // Star first, then drop the save: if the app dies in between, the
      // child keeps the star and at worst sees the finished puzzle again.
      final repository = _repository;
      unawaited(
        ref
            .read(progressProvider.notifier)
            .recordCompletion(args.puzzleId, args.difficulty)
            .then((_) => repository.clear()),
      );
      state = AsyncData(PuzzleState(setup: current.setup, completed: true));
    } else {
      if (result == DropResult.placed) audio.play(Sfx.place);
      unawaited(_repository.save(current.session));
    }
  }

  void playAgain() {
    final current = state.value;
    if (current == null) return;
    unawaited(_repository.clear());
    state = AsyncData(
      PuzzleState(
        setup: current.setup.withSession(
          newSession(args.puzzleId, args.difficulty),
        ),
      ),
    );
  }
}

final puzzleControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PuzzleController, PuzzleState, PuzzleArgs>(
      PuzzleController.new,
      retry: (_, _) => null,
    );

/// Picture for the "Next" button: the next one in the category the child
/// can play, wrapping around. Locked pictures are skipped, so the button
/// never leads a child into the paywall.
final nextPlayableProvider = Provider.autoDispose.family<PuzzleEntry?, String>((
  ref,
  puzzleId,
) {
  final manifest = ref.watch(manifestProvider).value;
  final fullAccess = ref.watch(fullAccessProvider).value ?? false;
  return manifest?.nextPuzzle(
    puzzleId,
    where: (entry) => canPlay(entry, fullAccess: fullAccess),
  );
});
