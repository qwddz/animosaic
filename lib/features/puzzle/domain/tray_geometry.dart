import 'dart:math';
import 'dart:ui';

import 'puzzle_layout.dart';

/// Slots of the scrollable piece tray. Pieces fill rows across the tray's
/// thickness, and the tray scrolls along its long axis.
class TrayGeometry {
  TrayGeometry({required PuzzleLayout layout, required Size pieceSize})
    : rect = layout.tray,
      side = layout.traySide,
      _pieceExtent = max(pieceSize.width, pieceSize.height) {
    final usable = max(1.0, _thickness - 2 * padding);
    slot = min(_pieceExtent * 0.75, usable);
    perRow = max(1, (usable / slot).floor());
    pieceScale = slot * 0.92 / _pieceExtent;
  }

  static const padding = 8.0;

  /// Space kept free at the start of a right-hand tray for the back button.
  static const leadingInset = 56.0;

  final Rect rect;
  final TraySide side;
  final double _pieceExtent;

  /// Square slot size for one piece.
  late final double slot;

  /// Slots across the tray thickness.
  late final int perRow;

  /// Scale of a piece resting in the tray.
  late final double pieceScale;

  double get _thickness => side == TraySide.right ? rect.width : rect.height;

  double get _length => side == TraySide.right ? rect.height : rect.width;

  double get _start => side == TraySide.right ? leadingInset : padding;

  /// Unit vector of the scroll axis.
  Offset get axis =>
      side == TraySide.right ? const Offset(0, 1) : const Offset(1, 0);

  double maxScroll(int count) {
    final rows = (count / perRow).ceil();
    return max(0.0, _start + rows * slot + padding - _length);
  }

  double clampScroll(double scroll, int count) =>
      scroll.clamp(0.0, maxScroll(count));

  /// Centre of the slot at [position] in the tray order.
  Offset slotCenter(int position, double scroll) {
    final row = position ~/ perRow;
    final across = position % perRow;
    final usedAcross = perRow * slot;
    final acrossStart = (_thickness - usedAcross) / 2;
    final acrossCenter = acrossStart + slot * (across + 0.5);
    final alongCenter = _start + slot * (row + 0.5) - scroll;
    return side == TraySide.right
        ? Offset(rect.left + acrossCenter, rect.top + alongCenter)
        : Offset(rect.left + alongCenter, rect.top + acrossCenter);
  }
}
