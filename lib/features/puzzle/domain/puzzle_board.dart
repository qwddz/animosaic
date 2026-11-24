import 'dart:math';
import 'dart:ui';

import 'piece_geometry.dart';
import 'puzzle_layout.dart';
import 'puzzle_session.dart';
import 'tray_geometry.dart';

enum DropResult { none, placed, loose, returnedToTray }

enum _GestureMode { undecided, scroll, drag }

/// Interaction rules of the puzzle screen, independent of rendering.
///
/// Keeps the wanted centre and scale of every piece in game coordinates;
/// the game moves its components towards them.
class PuzzleBoard {
  PuzzleBoard({
    required this.session,
    required this.layout,
    required this.geometry,
  }) : tray = TrayGeometry(layout: layout, pieceSize: geometry.pieceSize),
       positions = List.filled(session.pieces.length, Offset.zero),
       scales = List.filled(session.pieces.length, 1.0) {
    for (var i = 0; i < session.pieces.length; i++) {
      final piece = session.pieces[i];
      switch (piece.status) {
        case PieceStatus.placed:
          positions[i] = targetOf(i);
        case PieceStatus.loose:
          positions[i] = _clampToArea(_fromBoardUnits(piece.loose!));
        case PieceStatus.tray:
          break;
      }
    }
    _layoutTray();
  }

  /// Finger travel before a tray gesture is read as scroll or pick.
  static const dragSlop = 10.0;

  /// A tray gesture scrolls only when it runs this many times more along
  /// the tray than across it; a diagonal pull picks the piece. Children
  /// rarely pull a piece out at a right angle.
  static const scrollBias = 2.0;

  /// Snap distance as a share of the shorter cell side.
  static const snapRatio = 0.28;

  final PuzzleSession session;
  final PuzzleLayout layout;
  final PieceGeometry geometry;
  final TrayGeometry tray;
  final List<Offset> positions;
  final List<double> scales;

  double trayScroll = 0;

  int? _grabbed;
  int? _inHand;
  _GestureMode? _mode;
  Offset _pending = Offset.zero;

  /// Piece under the finger, including a tray gesture not yet decided.
  int? get grabbedPiece => _grabbed;

  /// Piece being carried by the finger.
  int? get carriedPiece => _mode == _GestureMode.drag ? _grabbed : null;

  double get snapDistance =>
      min(geometry.cellWidth, geometry.cellHeight) * snapRatio;

  Offset targetOf(int index) =>
      layout.board.topLeft + geometry.targetCenter(index);

  bool isDraggable(int index) =>
      session.pieces[index].status != PieceStatus.placed;

  /// Whether a touch [fromCenter] away from the piece's centre (game
  /// coordinates) grabs it. A piece resting in the tray is small, so its
  /// whole slot counts, not only its outline; elsewhere the caller tests the
  /// outline.
  bool hitsTraySlot(int index, Offset fromCenter) {
    if (session.pieces[index].status != PieceStatus.tray || index == _inHand) {
      return false;
    }
    final half = tray.slot / 2;
    return fromCenter.dx.abs() <= half && fromCenter.dy.abs() <= half;
  }

  bool dragStart(int index) {
    if (_grabbed != null || !isDraggable(index)) return false;
    _grabbed = index;
    _pending = Offset.zero;
    if (session.pieces[index].status == PieceStatus.tray) {
      _mode = _GestureMode.undecided;
    } else {
      _mode = _GestureMode.drag;
      _inHand = index;
    }
    return true;
  }

  void dragUpdate(Offset delta) {
    final index = _grabbed;
    if (index == null) return;
    switch (_mode!) {
      case _GestureMode.undecided:
        _pending += delta;
        if (_pending.distance < dragSlop) return;
        final along = _dot(_pending, tray.axis);
        final across = (_pending - tray.axis * along).distance;
        final canScroll = tray.maxScroll(session.trayOrder.length) > 0;
        if (canScroll && along.abs() > across * scrollBias) {
          _mode = _GestureMode.scroll;
          scrollBy(along);
        } else {
          _mode = _GestureMode.drag;
          _inHand = index;
          positions[index] += _pending;
          scales[index] = 1;
          _layoutTray();
        }
      case _GestureMode.scroll:
        scrollBy(_dot(delta, tray.axis));
      case _GestureMode.drag:
        positions[index] += delta;
    }
  }

  DropResult dragEnd() {
    final index = _grabbed;
    final mode = _mode;
    _grabbed = null;
    _mode = null;
    _inHand = null;
    if (index == null || mode != _GestureMode.drag) return DropResult.none;

    final result = _drop(index);
    _layoutTray();
    return result;
  }

  /// Moves the tray content by a finger movement along the scroll axis.
  void scrollBy(double fingerDelta) {
    trayScroll -= fingerDelta;
    _layoutTray();
  }

  DropResult _drop(int index) {
    final center = positions[index];
    if ((center - targetOf(index)).distance <= snapDistance) {
      positions[index] = targetOf(index);
      scales[index] = 1;
      session.place(index);
      return DropResult.placed;
    }
    // The gap next to the tray counts as tray, so no piece is left
    // half covering it.
    if (layout.tray.inflate(PuzzleLayout.gap).contains(center)) {
      session.returnToTray(index, position: _nearestTraySlot(center, index));
      return DropResult.returnedToTray;
    }
    positions[index] = _clampToArea(center);
    session.moveLoose(index, _toBoardUnits(positions[index]));
    return DropResult.loose;
  }

  /// Tray position whose slot is closest to [point], so a returned piece
  /// lands where the child dropped it, not off-screen.
  int _nearestTraySlot(Offset point, int dropped) {
    final count = session.trayOrder.where((i) => i != dropped).length;
    var best = 0;
    var bestDistance = double.infinity;
    for (var k = 0; k <= count; k++) {
      final distance = (tray.slotCenter(k, trayScroll) - point).distance;
      if (distance < bestDistance) {
        best = k;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _layoutTray() {
    final order = [
      for (final i in session.trayOrder)
        if (i != _inHand) i,
    ];
    trayScroll = tray.clampScroll(trayScroll, order.length);
    for (var k = 0; k < order.length; k++) {
      positions[order[k]] = tray.slotCenter(k, trayScroll);
      scales[order[k]] = tray.pieceScale;
    }
  }

  /// Keeps a loose piece on screen and its cell part off the tray.
  Offset _clampToArea(Offset center) {
    final halfW = geometry.cellWidth / 2;
    final halfH = geometry.cellHeight / 2;
    final trayEdge = layout.tray.inflate(PuzzleLayout.gap);
    final maxX = layout.traySide == TraySide.right
        ? trayEdge.left - halfW
        : layout.area.width - halfW;
    final maxY = layout.traySide == TraySide.bottom
        ? trayEdge.top - halfH
        : layout.area.height - halfH;
    return Offset(
      center.dx.clamp(halfW, max(halfW, maxX)),
      center.dy.clamp(halfH, max(halfH, maxY)),
    );
  }

  Offset _toBoardUnits(Offset center) {
    final board = layout.board;
    return Offset(
      (center.dx - board.left) / board.width,
      (center.dy - board.top) / board.height,
    );
  }

  Offset _fromBoardUnits(Offset units) {
    final board = layout.board;
    return Offset(
      board.left + units.dx * board.width,
      board.top + units.dy * board.height,
    );
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}
