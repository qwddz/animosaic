import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_layout.dart';

void main() {
  void expectBoardFits(PuzzleLayout layout) {
    final area = Offset.zero & layout.area;
    expect(area.contains(layout.board.topLeft), isTrue);
    expect(
      layout.board.right <= layout.area.width + 0.01 &&
          layout.board.bottom <= layout.area.height + 0.01,
      isTrue,
    );
    expect(layout.board.width / layout.board.height, closeTo(4 / 3, 0.001));
    expect(layout.board.overlaps(layout.tray), isFalse);
  }

  test('phone 20:9 puts the tray on the right', () {
    final layout = PuzzleLayout.compute(const Size(915, 411));
    expect(layout.traySide, TraySide.right);
    expect(layout.tray.width, greaterThanOrEqualTo(140));
    expectBoardFits(layout);
  });

  test('tablet 16:10 puts the tray on the right', () {
    final layout = PuzzleLayout.compute(const Size(1280, 800));
    expect(layout.traySide, TraySide.right);
    expectBoardFits(layout);
  });

  test('a squarish unfolded foldable puts the tray at the bottom', () {
    final layout = PuzzleLayout.compute(const Size(900, 840));
    expect(layout.traySide, TraySide.bottom);
    expect(layout.tray.height, greaterThanOrEqualTo(140));
    expectBoardFits(layout);
  });

  test('phones and tablets allow all four levels', () {
    for (final size in const [
      Size(915, 411),
      Size(640, 360),
      Size(1280, 800),
      Size(1024, 768),
    ]) {
      expect(
        PuzzleLayout.compute(size).availableDifficulties,
        Difficulty.values,
        reason: '$size',
      );
    }
  });

  test('expert is hidden when its pieces would be under 48 dp', () {
    final layout = PuzzleLayout.compute(const Size(560, 300));
    expect(layout.board.height / Difficulty.expert.rows, lessThan(48));
    expect(layout.allows(Difficulty.expert), isFalse);
    expect(layout.allows(Difficulty.hard), isTrue);
  });
}
