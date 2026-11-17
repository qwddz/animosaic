import '../../puzzle/domain/difficulty.dart';

/// Best difficulty the child has completed for each picture.
class PuzzleProgress {
  const PuzzleProgress([this._best = const {}]);

  final Map<String, Difficulty> _best;

  Difficulty? bestFor(String puzzleId) => _best[puzzleId];

  bool isCompleted(String puzzleId) => _best.containsKey(puzzleId);

  /// No picture completed yet.
  bool get isEmpty => _best.isEmpty;

  int completedCount(Iterable<String> puzzleIds) =>
      puzzleIds.where(isCompleted).length;

  /// Keeps the harder of the stored and the new difficulty.
  PuzzleProgress withCompletion(String puzzleId, Difficulty difficulty) {
    final current = _best[puzzleId];
    if (current != null && current.index >= difficulty.index) return this;
    return PuzzleProgress(Map.unmodifiable({..._best, puzzleId: difficulty}));
  }

  static const _jsonVersion = 1;

  Map<String, Object?> toJson() => {
    'version': _jsonVersion,
    'best': {for (final e in _best.entries) e.key: e.value.name},
  };

  /// Unknown difficulties are skipped. Returns null for data this version
  /// cannot read, including files written by a newer app version.
  static PuzzleProgress? fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['version'] != _jsonVersion) {
      return null;
    }
    final raw = json['best'];
    if (raw is! Map<String, Object?>) return null;
    final best = <String, Difficulty>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final difficulty = value is String ? Difficulty.byName(value) : null;
      if (difficulty != null) best[entry.key] = difficulty;
    }
    return PuzzleProgress(Map.unmodifiable(best));
  }
}
