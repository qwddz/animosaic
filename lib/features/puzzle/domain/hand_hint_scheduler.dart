import 'dart:ui';

import 'puzzle_board.dart';
import 'puzzle_session.dart';

/// Decides when the hand hint shows. Time is fed through [tick], so the
/// rules run without a real clock.
///
/// The hand shows after [currentDelay] of idle time, or at once in the
/// child's very first puzzle until the first touch. Every show after
/// that doubles the next wait, even one cut short by a touch; a correctly
/// placed piece resets it to [baseDelay].
class HandHintScheduler {
  HandHintScheduler({
    required bool firstPuzzle,
    this.baseDelay = const Duration(seconds: 8),
  }) : _delay = baseDelay {
    if (firstPuzzle) {
      _show();
      _welcome = true;
    }
  }

  /// Flights of the hand in one show.
  static const repeatsPerShow = 2;

  final Duration baseDelay;

  Duration _delay;
  Duration _idle = Duration.zero;
  bool _showing = false;
  bool _complete = false;
  int _showCount = 0;

  /// The first-puzzle show at the start; it does not lengthen the wait.
  bool _welcome = false;

  bool get showing => _showing;

  /// Shows started in this puzzle.
  int get showCount => _showCount;

  /// Idle time needed before the next show.
  Duration get currentDelay => _delay;

  void tick(Duration elapsed) {
    if (_complete || _showing) return;
    _idle += elapsed;
    if (_idle >= _delay) _show();
  }

  /// Any touch hides the hand and restarts the countdown, so the hand never
  /// appears in the middle of an attempt.
  void onTouch() {
    if (_showing) _endShow();
    _idle = Duration.zero;
  }

  /// The hand finished its flights.
  void onShowFinished() {
    if (_showing) _endShow();
    _idle = Duration.zero;
  }

  void onPiecePlaced() {
    _delay = baseDelay;
    _showing = false;
    _welcome = false;
    _idle = Duration.zero;
  }

  void onComplete() {
    _complete = true;
    _showing = false;
  }

  void _show() {
    if (_complete) return;
    _showing = true;
    _showCount++;
  }

  void _endShow() {
    _showing = false;
    if (!_welcome) _delay *= 2;
    _welcome = false;
  }
}

/// Piece the hand demonstrates: where it lies and where it belongs, in game
/// coordinates.
class HintTarget {
  const HintTarget({required this.index, required this.from, required this.to});

  final int index;
  final Offset from;
  final Offset to;
}

/// First tray piece visible in the tray, else the first loose piece on the
/// board, else null (the puzzle is complete).
HintTarget? pickHintPiece(PuzzleBoard board) {
  final grabbed = board.grabbedPiece;
  HintTarget target(int i) =>
      HintTarget(index: i, from: board.positions[i], to: board.targetOf(i));

  for (final i in board.session.trayOrder) {
    if (i != grabbed && board.layout.tray.contains(board.positions[i])) {
      return target(i);
    }
  }
  final pieces = board.session.pieces;
  for (var i = 0; i < pieces.length; i++) {
    if (i != grabbed && pieces[i].status == PieceStatus.loose) {
      return target(i);
    }
  }
  return null;
}
