import 'dart:math';
import 'dart:ui';

/// Which way the hand hint is mirrored around the piece it points at, so
/// the whole hand stays on screen.
class HandPlacement {
  const HandPlacement({required this.flipX, required this.flipY});

  /// Mirrors left-right: the hand reaches in from the left.
  final bool flipX;

  /// Mirrors up-down: the hand reaches in from above.
  final bool flipY;

  /// Picks one mirroring for a whole flight. Each stop is a piece centre and
  /// the unmirrored hand's bounds there; a side is mirrored when that leaves
  /// less of the hand outside [visible].
  static HandPlacement choose({
    required Rect visible,
    required List<(Offset, Rect)> stops,
  }) {
    var right = 0.0, left = 0.0, below = 0.0, above = 0.0;
    for (final (centre, hand) in stops) {
      right = max(right, hand.right - visible.right);
      left = max(left, visible.left - (2 * centre.dx - hand.right));
      below = max(below, hand.bottom - visible.bottom);
      above = max(above, visible.top - (2 * centre.dy - hand.bottom));
    }
    return HandPlacement(flipX: right > left, flipY: below > above);
  }

  /// [hand] mirrored around [centre].
  Rect apply(Rect hand, Offset centre) => Rect.fromLTRB(
    flipX ? 2 * centre.dx - hand.right : hand.left,
    flipY ? 2 * centre.dy - hand.bottom : hand.top,
    flipX ? 2 * centre.dx - hand.left : hand.right,
    flipY ? 2 * centre.dy - hand.top : hand.bottom,
  );

  /// An offset from the centre, mirrored.
  Offset mirror(Offset offset) =>
      Offset(flipX ? -offset.dx : offset.dx, flipY ? -offset.dy : offset.dy);

  /// Smallest shift that brings [rect] inside [visible]; when it is bigger
  /// than [visible], its top left edge wins.
  static Offset nudge(Rect rect, Rect visible) {
    double axis(double start, double end, double from, double to) {
      var d = 0.0;
      if (end > to) d = to - end;
      if (start + d < from) d = from - start;
      return d;
    }

    return Offset(
      axis(rect.left, rect.right, visible.left, visible.right),
      axis(rect.top, rect.bottom, visible.top, visible.bottom),
    );
  }
}
