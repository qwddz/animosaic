import 'dart:math';
import 'dart:ui';

import 'puzzle_cut.dart';

/// Pixel geometry of a [PuzzleCut] laid over a board of [boardSize].
class PieceGeometry {
  PieceGeometry({required this.cut, required this.boardSize});

  final PuzzleCut cut;
  final Size boardSize;

  /// Nominal knob height relative to the shorter cell side.
  static const tabRatio = 0.25;

  late final double cellWidth = boardSize.width / cut.columns;
  late final double cellHeight = boardSize.height / cut.rows;
  late final double tabSize = min(cellWidth, cellHeight) * tabRatio;

  /// Room around the cell that a knob can reach.
  late final double margin = tabSize * EdgeShape.maxSize;

  /// Size of the box that holds a piece with all its knobs.
  late final Size pieceSize = Size(
    cellWidth + 2 * margin,
    cellHeight + 2 * margin,
  );

  Rect cellRect(int index) => Rect.fromLTWH(
    cut.columnOf(index) * cellWidth,
    cut.rowOf(index) * cellHeight,
    cellWidth,
    cellHeight,
  );

  /// Where the piece centre belongs, relative to the board's top-left corner.
  Offset targetCenter(int index) => cellRect(index).center;

  /// Piece box on the board, relative to the board's top-left corner.
  Rect pieceBox(int index) => cellRect(index).inflate(margin);

  /// Piece outline in piece-local coordinates (origin at the box top-left).
  Path piecePath(int index) {
    final cell = cellRect(index);
    final shift = Offset(margin - cell.left, margin - cell.top);
    final path = Path();
    final tl = cell.topLeft, tr = cell.topRight;
    final br = cell.bottomRight, bl = cell.bottomLeft;

    final top = _edgeCurve(tl, tr, const Offset(0, 1), cut.topEdge(index));
    final right = _edgeCurve(tr, br, const Offset(1, 0), cut.rightEdge(index));
    final bottom = _reverse(
      _edgeCurve(bl, br, const Offset(0, 1), cut.bottomEdge(index)),
    );
    final left = _reverse(
      _edgeCurve(tl, bl, const Offset(1, 0), cut.leftEdge(index)),
    );

    final start = top.first + shift;
    path.moveTo(start.dx, start.dy);
    for (final curve in [top, right, bottom, left]) {
      for (var i = 1; i < curve.length; i += 3) {
        final c1 = curve[i] + shift;
        final c2 = curve[i + 1] + shift;
        final end = curve[i + 2] + shift;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      }
    }
    path.close();
    return path;
  }

  /// Knob template: cubic segments (c1, c2, end) from (0, 0) to (1, 0);
  /// x runs along the edge, y is the knob height (1 = full tab size).
  static const _template = <List<double>>[
    [0.00, 0.00, 0.38, 0.00, 0.38, 0.00],
    [0.42, 0.00, 0.44, 0.25, 0.40, 0.45],
    [0.34, 0.75, 0.40, 1.00, 0.50, 1.00],
    [0.60, 1.00, 0.66, 0.75, 0.60, 0.45],
    [0.56, 0.25, 0.58, 0.00, 0.62, 0.00],
    [0.62, 0.00, 1.00, 0.00, 1.00, 0.00],
  ];

  /// Points `[start, c1, c2, end, c1, c2, end, ...]` of the edge from [a]
  /// to [b] in its canonical direction; [normal] is the positive side.
  List<Offset> _edgeCurve(Offset a, Offset b, Offset normal, EdgeShape? edge) {
    if (edge == null) return [a, a, b, b];
    final along = b - a;
    final shift = edge.center - 0.5;
    final height = tabSize * edge.size * edge.bulge;
    Offset point(double x, double y) {
      final shiftedX = (x == 0 || x == 1) ? x : x + shift;
      return a + along * shiftedX + normal * (y * height);
    }

    final points = <Offset>[a];
    for (final s in _template) {
      points
        ..add(point(s[0], s[1]))
        ..add(point(s[2], s[3]))
        ..add(point(s[4], s[5]));
    }
    return points;
  }

  /// Same curve traversed backwards.
  static List<Offset> _reverse(List<Offset> curve) {
    final reversed = <Offset>[curve.last];
    for (var i = curve.length - 1; i > 0; i -= 3) {
      reversed
        ..add(curve[i - 1])
        ..add(curve[i - 2])
        ..add(curve[i - 3]);
    }
    return reversed;
  }
}
