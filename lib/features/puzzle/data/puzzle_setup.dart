import 'dart:math';
import 'dart:ui' as ui;

import '../../catalog/domain/content_manifest.dart';
import '../../content/data/picture_store.dart';
import '../domain/difficulty.dart';
import '../domain/puzzle_session.dart';
import 'session_repository.dart';

/// Everything the puzzle screen needs to start.
class PuzzleSetup {
  const PuzzleSetup({
    required this.entry,
    required this.session,
    required this.image,
  });

  final PuzzleEntry entry;
  final PuzzleSession session;
  final ui.Image image;

  PuzzleSetup withSession(PuzzleSession session) =>
      PuzzleSetup(entry: entry, session: session, image: image);
}

PuzzleSession newSession(String puzzleId, Difficulty difficulty) =>
    PuzzleSession.start(
      puzzleId: puzzleId,
      difficulty: difficulty,
      seed: Random().nextInt(1 << 31),
    );

/// Resumes the saved session for this puzzle and difficulty, if any.
/// The picture is decoded at full size (2048 × 1536, about 12 MB), so the
/// result does not depend on the screen and survives resizes. A CDN picture
/// is downloaded first if it is not cached; [onProgress] follows that.
Future<PuzzleSetup> loadPuzzleSetup({
  required ContentManifest manifest,
  required SessionRepository repository,
  required PictureStore pictures,
  required String puzzleId,
  required Difficulty difficulty,
  void Function(double progress)? onProgress,
}) async {
  final entry = manifest.puzzleById(puzzleId);
  if (entry == null) throw StateError('Puzzle $puzzleId is not in the catalog');
  final session =
      await repository.load(puzzleId, difficulty) ??
      newSession(puzzleId, difficulty);
  final bytes = await pictures.load(entry, onProgress: onProgress);
  final codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame;
  try {
    frame = await codec.getNextFrame();
  } finally {
    codec.dispose();
  }
  return PuzzleSetup(entry: entry, session: session, image: frame.image);
}
