import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/hand_hint_scheduler.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_board.dart';

import 'puzzle_board_test.dart' show newBoard, pickMove;

const _s = Duration(seconds: 1);

void main() {
  group('HandHintScheduler', () {
    test('first puzzle shows immediately', () {
      final hint = HandHintScheduler(firstPuzzle: true);
      expect(hint.showing, isTrue);
      hint.tick(Duration.zero);
      expect(hint.showing, isTrue);
      expect(hint.showCount, 1);
    });

    test('not first puzzle shows after 8 s idle', () {
      final hint = HandHintScheduler(firstPuzzle: false);
      expect(hint.showing, isFalse);
      hint.tick(_s * 7.9);
      expect(hint.showing, isFalse);
      hint.tick(_s * 0.1);
      expect(hint.showing, isTrue);
      expect(hint.showCount, 1);
    });

    test('touch hides and restarts the 8 s countdown', () {
      final hint = HandHintScheduler(firstPuzzle: false)
        ..tick(_s * 7)
        ..onTouch()
        ..tick(_s * 7);
      expect(hint.showing, isFalse);
      hint.tick(_s);
      expect(hint.showing, isTrue);
      hint.onTouch();
      expect(hint.showing, isFalse);
    });

    test('first puzzle: after a touch the normal countdown applies', () {
      final hint = HandHintScheduler(firstPuzzle: true)..onTouch();
      expect(hint.showing, isFalse);
      hint.tick(_s * 7);
      expect(hint.showing, isFalse);
      hint.tick(_s);
      expect(hint.showing, isTrue);
      expect(hint.currentDelay, _s * 8);
    });

    test('drag in progress keeps it hidden', () {
      final hint = HandHintScheduler(firstPuzzle: false);
      for (var t = 0; t < 30; t += 2) {
        hint
          ..tick(_s * 2)
          ..onTouch();
        expect(hint.showing, isFalse);
      }
      expect(hint.showCount, 0);
    });

    test('next show waits double', () {
      final hint = HandHintScheduler(firstPuzzle: false)..tick(_s * 8);
      expect(hint.showing, isTrue);
      hint.onShowFinished();
      expect(hint.showing, isFalse);
      expect(hint.currentDelay, _s * 16);
      hint.tick(_s * 15);
      expect(hint.showing, isFalse);
      hint.tick(_s);
      expect(hint.showing, isTrue);
      hint.onShowFinished();
      expect(hint.currentDelay, _s * 32);
      hint.tick(_s * 31);
      expect(hint.showing, isFalse);
      hint.tick(_s);
      expect(hint.showing, isTrue);
      expect(hint.showCount, 3);
    });

    test('a show cut short by a touch also doubles the wait', () {
      final hint = HandHintScheduler(firstPuzzle: false)
        ..tick(_s * 8)
        ..onTouch();
      expect(hint.currentDelay, _s * 16);
      // Further touches with no show in between keep the wait.
      hint.onTouch();
      expect(hint.currentDelay, _s * 16);
    });

    test('placed piece resets the wait to 8 s', () {
      final hint = HandHintScheduler(firstPuzzle: false)
        ..tick(_s * 8)
        ..onShowFinished()
        ..tick(_s * 16)
        ..onShowFinished();
      expect(hint.currentDelay, _s * 32);
      hint.onPiecePlaced();
      expect(hint.currentDelay, _s * 8);
      hint.tick(_s * 8);
      expect(hint.showing, isTrue);
    });

    test('placed piece ends first-puzzle mode', () {
      final hint = HandHintScheduler(firstPuzzle: true)
        ..onTouch()
        ..onPiecePlaced();
      hint.tick(Duration.zero);
      expect(hint.showing, isFalse);
    });

    test('completed puzzle never shows', () {
      final hint = HandHintScheduler(firstPuzzle: true)..onComplete();
      expect(hint.showing, isFalse);
      hint.tick(const Duration(minutes: 10));
      expect(hint.showing, isFalse);
      hint
        ..onTouch()
        ..onPiecePlaced()
        ..tick(const Duration(minutes: 10));
      expect(hint.showing, isFalse);
    });

    test('two repeats per show', () {
      expect(HandHintScheduler.repeatsPerShow, 2);
    });
  });

  group('pickHintPiece', () {
    const phone = Size(915, 411);

    test('prefers a visible tray piece', () {
      final board = newBoard(phone, Difficulty.expert);
      final target = pickHintPiece(board)!;
      final first = board.session.trayOrder.first;
      expect(target.index, first);
      expect(target.from, board.positions[first]);
      expect(target.to, board.targetOf(first));
    });

    test('skips tray pieces scrolled out of view', () {
      final board = newBoard(phone, Difficulty.expert);
      board.scrollBy(-10000);
      final target = pickHintPiece(board)!;
      expect(target.index, isNot(board.session.trayOrder.first));
      expect(board.layout.tray.contains(target.from), isTrue);
    });

    test('falls back to a loose piece when the tray is empty', () {
      final board = newBoard(phone, Difficulty.easy);
      final loose = <int>[];
      while (board.session.trayOrder.isNotEmpty) {
        final piece = board.session.trayOrder.first;
        board.dragStart(piece);
        board.dragUpdate(pickMove(board));
        // Leave it on the board, away from its target.
        final spot = board.layout.board.topLeft + const Offset(5, 5);
        board.dragUpdate(spot - board.positions[piece]);
        if (board.dragEnd() == DropResult.loose) loose.add(piece);
      }
      expect(loose, isNotEmpty);
      final target = pickHintPiece(board)!;
      expect(loose, contains(target.index));
      expect(target.from, board.positions[target.index]);
      expect(target.to, board.targetOf(target.index));
    });

    test('null when complete', () {
      final board = newBoard(phone, Difficulty.easy);
      for (var i = 0; i < board.session.pieces.length; i++) {
        board.session.place(i);
      }
      expect(pickHintPiece(board), isNull);
    });
  });
}
