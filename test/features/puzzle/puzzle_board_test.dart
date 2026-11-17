import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/piece_geometry.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_board.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_cut.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_layout.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_session.dart';

PuzzleBoard newBoard(Size area, Difficulty difficulty, {int seed = 3}) {
  final layout = PuzzleLayout.compute(area);
  final session = PuzzleSession.start(
    puzzleId: 'p',
    difficulty: difficulty,
    seed: seed,
  );
  final cut = PuzzleCut.generate(
    columns: difficulty.columns,
    rows: difficulty.rows,
    seed: seed,
  );
  return PuzzleBoard(
    session: session,
    layout: layout,
    geometry: PieceGeometry(cut: cut, boardSize: layout.board.size),
  );
}

/// Finger movement across the tray's scroll axis, which picks a piece.
Offset pickMove(PuzzleBoard board) => board.tray.axis == const Offset(0, 1)
    ? const Offset(-20, 0)
    : const Offset(0, -20);

void main() {
  const screens = {
    'phone 20:9': Size(915, 411),
    'small phone 16:9': Size(640, 360),
    'tablet 16:10': Size(1280, 800),
    'tablet 4:3': Size(1024, 768),
    'unfolded foldable': Size(900, 840),
  };

  for (final MapEntry(key: name, value: size) in screens.entries) {
    for (final difficulty in PuzzleLayout.compute(size).availableDifficulties) {
      test('$name: ${difficulty.name} can be solved from the tray', () {
        final board = newBoard(size, difficulty);
        while (!board.session.isComplete) {
          final piece = board.session.trayOrder.first;
          final slot = board.positions[piece];
          expect(
            board.layout.tray.contains(slot),
            isTrue,
            reason: 'first tray slot is on screen',
          );
          expect(board.dragStart(piece), isTrue);
          board.dragUpdate(pickMove(board));
          expect(board.carriedPiece, piece);
          board.dragUpdate(board.targetOf(piece) - board.positions[piece]);
          expect(board.dragEnd(), DropResult.placed);
        }
        expect(board.session.placedCount, difficulty.pieceCount);
      });
    }
  }

  test('moving along the tray scrolls it instead of picking', () {
    final board = newBoard(const Size(915, 411), Difficulty.expert);
    final piece = board.session.trayOrder.first;
    final before = board.positions[piece];
    board.dragStart(piece);
    board.dragUpdate(const Offset(0, -15));
    board.dragUpdate(const Offset(0, -60));
    expect(board.carriedPiece, isNull);
    expect(board.trayScroll, closeTo(75, 0.001));
    expect(board.positions[piece].dy, closeTo(before.dy - 75, 0.001));
    expect(board.dragEnd(), DropResult.none);
    expect(board.session.pieces[piece].status, PieceStatus.tray);
  });

  test('scrolling stops at both ends of the tray', () {
    final board = newBoard(const Size(915, 411), Difficulty.expert);
    board.scrollBy(500);
    expect(board.trayScroll, 0);
    board.scrollBy(-100000);
    expect(board.trayScroll, board.tray.maxScroll(48));
    expect(board.tray.maxScroll(48), greaterThan(0));
  });

  test('a piece dropped away from its place stays loose', () {
    final board = newBoard(const Size(915, 411), Difficulty.medium);
    final piece = board.session.trayOrder.first;
    final wrong =
        board.targetOf(piece) +
        Offset(board.snapDistance * 2, board.snapDistance * 2);
    board.dragStart(piece);
    board.dragUpdate(pickMove(board));
    board.dragUpdate(wrong - board.positions[piece]);
    expect(board.dragEnd(), DropResult.loose);
    expect(board.session.pieces[piece].status, PieceStatus.loose);
    expect(board.session.trayOrder, isNot(contains(piece)));

    // A loose piece is picked up directly and can then be placed.
    expect(board.dragStart(piece), isTrue);
    expect(board.carriedPiece, piece);
    board.dragUpdate(board.targetOf(piece) - board.positions[piece]);
    expect(board.dragEnd(), DropResult.placed);
  });

  test('snaps just inside the threshold and not outside it', () {
    final board = newBoard(const Size(915, 411), Difficulty.easy);
    final piece = board.session.trayOrder.first;
    board.dragStart(piece);
    board.dragUpdate(pickMove(board));
    final near = board.targetOf(piece) + Offset(board.snapDistance + 1, 0);
    board.dragUpdate(near - board.positions[piece]);
    expect(board.dragEnd(), DropResult.loose);

    board.dragStart(piece);
    board.dragUpdate(const Offset(-2, 0));
    expect(board.dragEnd(), DropResult.placed);
    expect(board.isDraggable(piece), isFalse);
    expect(board.dragStart(piece), isFalse);
  });

  test('a piece dropped over the tray lands in the nearest slot', () {
    final board = newBoard(const Size(915, 411), Difficulty.medium);
    final piece = board.session.trayOrder[0];
    board.dragStart(piece);
    board.dragUpdate(pickMove(board));
    // Drop on the slot that the third remaining piece occupies now.
    final third = board.session.trayOrder[3];
    board.dragUpdate(board.positions[third] - board.positions[piece]);
    expect(board.dragEnd(), DropResult.returnedToTray);
    expect(board.session.trayOrder.indexOf(piece), 2);
    expect(board.scales[piece], board.tray.pieceScale);
  });

  test('a returned piece stays visible in a scrolled tray', () {
    final board = newBoard(const Size(915, 411), Difficulty.expert);
    board.scrollBy(-300);
    expect(board.trayScroll, greaterThan(0));
    final piece = board.session.trayOrder[20];
    final dropAt = Offset(board.layout.tray.center.dx, 200);
    board.dragStart(piece);
    board.dragUpdate(pickMove(board));
    board.dragUpdate(dropAt - board.positions[piece]);
    expect(board.dragEnd(), DropResult.returnedToTray);
    expect(board.layout.tray.contains(board.positions[piece]), isTrue);
    expect(
      (board.positions[piece] - dropAt).distance,
      lessThan(board.tray.slot * 1.5),
    );
  });

  test('dropping in the gap next to the tray returns the piece', () {
    final board = newBoard(const Size(915, 411), Difficulty.medium);
    final piece = board.session.trayOrder.first;
    final gap = Offset(board.layout.tray.left - 4, 200);
    board.dragStart(piece);
    board.dragUpdate(pickMove(board));
    board.dragUpdate(gap - board.positions[piece]);
    expect(board.dragEnd(), DropResult.returnedToTray);
  });

  test('loose pieces keep their cell off the tray', () {
    for (final size in const [Size(915, 411), Size(900, 840)]) {
      final board = newBoard(size, Difficulty.easy);
      final piece = board.session.trayOrder.first;
      // Drop on the board's far edge, next to the tray.
      final edge = board.layout.traySide == TraySide.right
          ? Offset(board.layout.board.right - 5, 100)
          : Offset(100, board.layout.board.bottom - 5);
      board.dragStart(piece);
      board.dragUpdate(pickMove(board));
      board.dragUpdate(edge - board.positions[piece]);
      expect(board.dragEnd(), DropResult.loose);
      final cell = Rect.fromCenter(
        center: board.positions[piece],
        width: board.geometry.cellWidth,
        height: board.geometry.cellHeight,
      );
      expect(cell.overlaps(board.layout.tray), isFalse, reason: '$size');
    }
  });

  test('restores loose and placed pieces from a saved session', () {
    final first = newBoard(const Size(915, 411), Difficulty.medium);
    final session = first.session
      ..place(0)
      ..moveLoose(1, const Offset(0.5, 0.5));
    final layout = PuzzleLayout.compute(const Size(1280, 800));
    final restored = PuzzleBoard(
      session: session,
      layout: layout,
      geometry: PieceGeometry(
        cut: PuzzleCut.generate(columns: 4, rows: 3, seed: 3),
        boardSize: layout.board.size,
      ),
    );
    expect(restored.positions[0], restored.targetOf(0));
    expect(restored.positions[1], layout.board.center);
  });
}
