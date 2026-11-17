import 'dart:math';
import 'dart:ui';

import 'difficulty.dart';

enum TraySide { right, bottom }

/// Splits the play area into the board (picture aspect) and the piece tray.
class PuzzleLayout {
  const PuzzleLayout._({
    required this.area,
    required this.board,
    required this.tray,
    required this.traySide,
  });

  /// Picks the tray side that leaves the bigger board.
  factory PuzzleLayout.compute(Size area, {double imageAspect = 4 / 3}) {
    final inner = (Offset.zero & area).deflate(padding);
    final right = _rightTray(area, inner, imageAspect);
    final bottom = _bottomTray(area, inner, imageAspect);
    final rightArea = right.board.width * right.board.height;
    final bottomArea = bottom.board.width * bottom.board.height;
    return bottomArea > rightArea ? bottom : right;
  }

  static const padding = 12.0;
  static const gap = 12.0;
  static const minTrayThickness = 140.0;

  /// Smallest comfortable piece side for a finger, in logical pixels.
  static const minPieceSide = 48.0;

  final Size area;
  final Rect board;

  /// Tray extends to the screen edges along its scroll axis, so pieces
  /// scrolled out of it leave the screen instead of covering the board.
  final Rect tray;
  final TraySide traySide;

  bool allows(Difficulty difficulty) =>
      board.width / difficulty.columns >= minPieceSide &&
      board.height / difficulty.rows >= minPieceSide;

  List<Difficulty> get availableDifficulties =>
      Difficulty.values.where(allows).toList();

  static PuzzleLayout _rightTray(Size area, Rect inner, double aspect) {
    final height = min(
      inner.height,
      max(0.0, inner.width - minTrayThickness - gap) / aspect,
    );
    final width = height * aspect;
    final board = Rect.fromLTWH(
      inner.left,
      inner.top + (inner.height - height) / 2,
      width,
      height,
    );
    final trayLeft = board.right + gap;
    return PuzzleLayout._(
      area: area,
      board: board,
      tray: Rect.fromLTRB(trayLeft, 0, area.width, area.height),
      traySide: TraySide.right,
    );
  }

  static PuzzleLayout _bottomTray(Size area, Rect inner, double aspect) {
    final width = min(
      inner.width,
      max(0.0, inner.height - minTrayThickness - gap) * aspect,
    );
    final height = width / aspect;
    final board = Rect.fromLTWH(
      inner.left + (inner.width - width) / 2,
      inner.top,
      width,
      height,
    );
    final trayTop = board.bottom + gap;
    return PuzzleLayout._(
      area: area,
      board: board,
      tray: Rect.fromLTRB(0, trayTop, area.width, area.height),
      traySide: TraySide.bottom,
    );
  }
}
