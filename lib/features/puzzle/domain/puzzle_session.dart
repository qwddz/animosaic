import 'dart:math';
import 'dart:ui';

import 'difficulty.dart';

enum PieceStatus { tray, loose, placed }

class PieceState {
  PieceState(this.status, [this.loose]);

  PieceStatus status;

  /// Centre of a loose piece relative to the board, in board sizes
  /// (0..1 inside the board). Null unless [status] is loose.
  Offset? loose;
}

/// Saveable state of one puzzle in progress. The cut and the initial tray
/// order are recreated from [seed].
class PuzzleSession {
  PuzzleSession._({
    required this.puzzleId,
    required this.difficulty,
    required this.seed,
    required this.pieces,
    required this.trayOrder,
  });

  /// All pieces start in the tray, shuffled.
  factory PuzzleSession.start({
    required String puzzleId,
    required Difficulty difficulty,
    required int seed,
  }) {
    final count = difficulty.pieceCount;
    final order = List<int>.generate(count, (i) => i)
      ..shuffle(Random(seed + 1));
    return PuzzleSession._(
      puzzleId: puzzleId,
      difficulty: difficulty,
      seed: seed,
      pieces: [for (var i = 0; i < count; i++) PieceState(PieceStatus.tray)],
      trayOrder: order,
    );
  }

  final String puzzleId;
  final Difficulty difficulty;
  final int seed;
  final List<PieceState> pieces;

  /// Pieces in the tray, in display order.
  final List<int> trayOrder;

  bool get isComplete => pieces.every((p) => p.status == PieceStatus.placed);

  /// Whether the child has moved anything, so the session is worth saving.
  bool get hasProgress => pieces.any((p) => p.status != PieceStatus.tray);

  int get placedCount =>
      pieces.where((p) => p.status == PieceStatus.placed).length;

  void place(int index) {
    trayOrder.remove(index);
    pieces[index] = PieceState(PieceStatus.placed);
  }

  void moveLoose(int index, Offset normalizedCenter) {
    trayOrder.remove(index);
    pieces[index] = PieceState(PieceStatus.loose, normalizedCenter);
  }

  /// Puts the piece back into the tray at [position] in the tray order.
  void returnToTray(int index, {int position = 0}) {
    trayOrder.remove(index);
    trayOrder.insert(position.clamp(0, trayOrder.length), index);
    pieces[index] = PieceState(PieceStatus.tray);
  }

  static const _jsonVersion = 1;

  Map<String, Object?> toJson() => {
    'version': _jsonVersion,
    'puzzleId': puzzleId,
    'difficulty': difficulty.name,
    'seed': seed,
    'pieces': [
      for (final piece in pieces)
        {
          'status': piece.status.name,
          if (piece.loose != null) 'x': piece.loose!.dx,
          if (piece.loose != null) 'y': piece.loose!.dy,
        },
    ],
    'trayOrder': trayOrder,
  };

  /// Returns null for data that is not a consistent session.
  static PuzzleSession? fromJson(Object? json) {
    try {
      if (json is! Map<String, Object?>) return null;
      if (json['version'] != _jsonVersion) return null;
      final difficulty = Difficulty.byName(json['difficulty'] as String?);
      final puzzleId = json['puzzleId'];
      final seed = json['seed'];
      final rawPieces = json['pieces'];
      final rawTray = json['trayOrder'];
      if (difficulty == null ||
          puzzleId is! String ||
          seed is! int ||
          rawPieces is! List ||
          rawTray is! List ||
          rawPieces.length != difficulty.pieceCount) {
        return null;
      }
      final pieces = <PieceState>[];
      for (final raw in rawPieces) {
        final map = raw as Map<String, Object?>;
        final status = PieceStatus.values.byName(map['status'] as String);
        if (status == PieceStatus.loose) {
          final x = (map['x'] as num).toDouble();
          final y = (map['y'] as num).toDouble();
          pieces.add(PieceState(status, Offset(x, y)));
        } else {
          pieces.add(PieceState(status));
        }
      }
      final trayOrder = rawTray.cast<int>().toList();
      final inTray = {
        for (var i = 0; i < pieces.length; i++)
          if (pieces[i].status == PieceStatus.tray) i,
      };
      if (trayOrder.length != inTray.length ||
          !trayOrder.toSet().containsAll(inTray)) {
        return null;
      }
      return PuzzleSession._(
        puzzleId: puzzleId,
        difficulty: difficulty,
        seed: seed,
        pieces: pieces,
        trayOrder: trayOrder,
      );
    } on Object {
      return null;
    }
  }
}
