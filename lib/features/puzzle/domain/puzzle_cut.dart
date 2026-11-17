import 'dart:math';

/// How one side of a piece looks from that piece's point of view.
enum EdgeKind { flat, tab, blank }

/// Shape of one internal edge. Both pieces on its sides trace the same curve,
/// so they always fit.
class EdgeShape {
  const EdgeShape({
    required this.bulge,
    required this.center,
    required this.size,
  });

  /// +1: the knob bulges to the positive side of the edge (down for a
  /// horizontal edge, right for a vertical one); -1: to the negative side.
  final int bulge;

  /// Knob centre along the edge, as a fraction of the edge length.
  final double center;

  /// Knob height relative to the nominal tab size.
  final double size;

  static const minSize = 0.9;
  static const maxSize = 1.1;
  static const maxCenterShift = 0.06;
}

/// Procedural jigsaw cut of a grid: which way every internal knob points.
class PuzzleCut {
  PuzzleCut._(this.columns, this.rows, this._horizontal, this._vertical);

  /// The same [seed] always produces the same cut.
  factory PuzzleCut.generate({
    required int columns,
    required int rows,
    required int seed,
  }) {
    final random = Random(seed);
    EdgeShape next() => EdgeShape(
      bulge: random.nextBool() ? 1 : -1,
      center: 0.5 + (random.nextDouble() * 2 - 1) * EdgeShape.maxCenterShift,
      size:
          EdgeShape.minSize +
          random.nextDouble() * (EdgeShape.maxSize - EdgeShape.minSize),
    );
    final horizontal = [
      for (var r = 0; r < rows - 1; r++)
        [for (var c = 0; c < columns; c++) next()],
    ];
    final vertical = [
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < columns - 1; c++) next()],
    ];
    return PuzzleCut._(columns, rows, horizontal, vertical);
  }

  final int columns;
  final int rows;

  /// `_horizontal[r][c]`: edge between rows r and r + 1 in column c.
  final List<List<EdgeShape>> _horizontal;

  /// `_vertical[r][c]`: edge between columns c and c + 1 in row r.
  final List<List<EdgeShape>> _vertical;

  int get pieceCount => columns * rows;

  int rowOf(int index) => index ~/ columns;

  int columnOf(int index) => index % columns;

  /// Edge on top of the piece, or null on the picture border.
  EdgeShape? topEdge(int index) {
    final r = rowOf(index);
    return r > 0 ? _horizontal[r - 1][columnOf(index)] : null;
  }

  EdgeShape? bottomEdge(int index) {
    final r = rowOf(index);
    return r < rows - 1 ? _horizontal[r][columnOf(index)] : null;
  }

  EdgeShape? leftEdge(int index) {
    final c = columnOf(index);
    return c > 0 ? _vertical[rowOf(index)][c - 1] : null;
  }

  EdgeShape? rightEdge(int index) {
    final c = columnOf(index);
    return c < columns - 1 ? _vertical[rowOf(index)][c] : null;
  }

  /// Edge kinds of a piece in the order top, right, bottom, left.
  List<EdgeKind> edgeKinds(int index) {
    EdgeKind kind(EdgeShape? edge, int outward) {
      if (edge == null) return EdgeKind.flat;
      return edge.bulge == outward ? EdgeKind.tab : EdgeKind.blank;
    }

    return [
      kind(topEdge(index), -1),
      kind(rightEdge(index), 1),
      kind(bottomEdge(index), 1),
      kind(leftEdge(index), -1),
    ];
  }
}
