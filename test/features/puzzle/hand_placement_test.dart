import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/hand_placement.dart';

void main() {
  const visible = Rect.fromLTWH(0, 0, 900, 400);
  // A hand that hangs down and right of a point 10 below-right of the centre.
  Rect handAt(Offset c) => Rect.fromLTWH(c.dx, c.dy + 10, 60, 80);

  test('a hand that fits keeps its natural side', () {
    const c = Offset(300, 150);
    final p = HandPlacement.choose(visible: visible, stops: [(c, handAt(c))]);
    expect(p.flipX, isFalse);
    expect(p.flipY, isFalse);
  });

  test('a hand past the bottom edge flips up', () {
    const from = Offset(700, 100);
    const to = Offset(300, 360);
    final p = HandPlacement.choose(
      visible: visible,
      stops: [(from, handAt(from)), (to, handAt(to))],
    );
    expect(p.flipY, isTrue);
    expect(p.flipX, isFalse);
    final mirrored = p.apply(handAt(to), to);
    expect(mirrored.bottom, lessThanOrEqualTo(visible.bottom));
    expect(mirrored.top, greaterThanOrEqualTo(visible.top));
  });

  test('a hand past the right edge flips left', () {
    const c = Offset(870, 150);
    final p = HandPlacement.choose(visible: visible, stops: [(c, handAt(c))]);
    expect(p.flipX, isTrue);
    expect(p.flipY, isFalse);
    expect(p.apply(handAt(c), c).right, lessThanOrEqualTo(visible.right));
  });

  test('mirroring is around the centre', () {
    const p = HandPlacement(flipX: true, flipY: true);
    expect(
      p.apply(const Rect.fromLTRB(110, 120, 150, 200), const Offset(100, 100)),
      const Rect.fromLTRB(50, 0, 90, 80),
    );
    expect(p.mirror(const Offset(12, 18)), const Offset(-12, -18));
  });

  test('nudge moves a rect back inside, and nothing when it fits', () {
    expect(
      HandPlacement.nudge(const Rect.fromLTWH(10, 10, 50, 50), visible),
      Offset.zero,
    );
    expect(
      HandPlacement.nudge(const Rect.fromLTWH(880, 370, 50, 50), visible),
      const Offset(-30, -20),
    );
    expect(
      HandPlacement.nudge(const Rect.fromLTWH(-5, -8, 50, 50), visible),
      const Offset(5, 8),
    );
  });
}
