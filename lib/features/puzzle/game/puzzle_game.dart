import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';

import '../domain/hand_hint_scheduler.dart';
import '../domain/piece_geometry.dart';
import '../domain/puzzle_board.dart';
import '../domain/puzzle_cut.dart';
import '../domain/puzzle_layout.dart';
import '../domain/puzzle_session.dart';
import 'board_component.dart';
import 'hand_hint_component.dart';
import 'piece_component.dart';
import 'piece_renderer.dart';
import 'tray_component.dart';

/// Puzzle screen game: renders [PuzzleBoard] and feeds it touch input.
class PuzzleGame extends FlameGame {
  PuzzleGame({
    required this.image,
    required this.session,
    required this.layout,
    required this.pixelRatio,
    required this.showHint,
    required this.handHint,
    required this.firstPuzzle,
    required this.reducedMotion,
    required this.onPiecePicked,
    required this.onPieceDropped,
  });

  final ui.Image image;
  final PuzzleSession session;
  final PuzzleLayout layout;
  final double pixelRatio;
  final bool showHint;

  /// Hand that shows where a piece goes; off means no hand at all.
  final bool handHint;

  /// The child's very first puzzle: the hand shows at once.
  final bool firstPuzzle;

  /// System "remove animations": the hand stands still.
  final bool reducedMotion;

  /// Called when the finger starts carrying a piece.
  final void Function() onPiecePicked;

  /// Called after every drop; the session already reflects it.
  final void Function(DropResult result) onPieceDropped;

  late final PuzzleBoard board;
  final _pieces = <PieceComponent>[];
  final _pieceImages = <ui.Image>[];

  /// Raise order of loose pieces: the last dropped one lies on top.
  final _looseOrder = <int, int>{};
  int _looseCounter = 0;

  /// Pointer that grabbed the current piece; other fingers are ignored.
  int? _pointer;
  bool _removed = false;

  HandHintScheduler? _hint;
  HandHintComponent? _hand;

  /// Fingers on the screen right now; the hand waits while any is down.
  int _touches = 0;

  static const _placedPriority = 10;
  static const _trayPriority = 100;
  static const _loosePriority = 200;
  static const _carriedPriority = 100000;
  static const _handPriority = 1000000;

  /// The hand on screen, if any. For tests.
  HandHintComponent? get handHintComponent => _hand;

  @override
  ui.Color backgroundColor() => const ui.Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final cut = PuzzleCut.generate(
      columns: session.difficulty.columns,
      rows: session.difficulty.rows,
      seed: session.seed,
    );
    final geometry = PieceGeometry(cut: cut, boardSize: layout.board.size);
    board = PuzzleBoard(session: session, layout: layout, geometry: geometry);

    add(BoardComponent(rect: layout.board, image: image, showHint: showHint));
    add(TrayComponent(rect: layout.tray)..priority = 1);

    final images = await Future.wait([
      for (var i = 0; i < cut.pieceCount; i++)
        renderPiece(
          source: image,
          geometry: geometry,
          index: i,
          pixelRatio: pixelRatio,
        ),
    ]);
    if (_removed) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    _pieceImages.addAll(images);
    final pieceSize = Vector2(
      geometry.pieceSize.width,
      geometry.pieceSize.height,
    );
    for (var i = 0; i < cut.pieceCount; i++) {
      if (session.pieces[i].status == PieceStatus.loose) {
        _looseOrder[i] = ++_looseCounter;
      }
      _pieces.add(
        PieceComponent(
          index: i,
          image: _pieceImages[i],
          outline: geometry.piecePath(i),
          size: pieceSize.clone(),
        ),
      );
    }
    await addAll(_pieces);
    for (final piece in _pieces) {
      piece.syncInstantly();
    }
    _refreshPriorities();
    if (handHint && !session.isComplete) {
      _hint = HandHintScheduler(
        firstPuzzle: firstPuzzle && session.placedCount == 0,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final hint = _hint;
    if (hint == null) return;
    if (_touches > 0 || board.grabbedPiece != null) {
      hint.onTouch();
    } else {
      hint.tick(Duration(microseconds: (dt * 1e6).round()));
    }
    _syncHand();
  }

  /// A finger touched the screen anywhere over the game.
  void touchDown() {
    _touches++;
    _touched();
  }

  void touchUp() {
    if (_touches > 0) _touches--;
  }

  void _touched() {
    _hint?.onTouch();
    _syncHand();
  }

  /// Adds or removes the hand to match the scheduler.
  void _syncHand() {
    final hint = _hint;
    if (hint == null) return;
    final hand = _hand;
    if (hint.showing && hand == null) {
      final target = pickHintPiece(board);
      if (target == null) {
        hint.onShowFinished();
        return;
      }
      add(
        _hand = HandHintComponent(
          target: target,
          pieceImage: _pieceImages[target.index],
          pieceSize: board.geometry.pieceSize,
          cellSide: math.min(
            board.geometry.cellWidth,
            board.geometry.cellHeight,
          ),
          visible: (ui.Offset.zero & layout.area).deflate(4),
          fromScale: board.scales[target.index],
          reducedMotion: reducedMotion,
          onFinished: () {
            hint.onShowFinished();
            _syncHand();
          },
          priority: _handPriority,
        ),
      );
    } else if (!hint.showing && hand != null) {
      hand.removeFromParent();
      _hand = null;
    }
  }

  void pieceDragStart(int index, int pointerId) {
    _touched();
    if (!board.dragStart(index)) return;
    _pointer = pointerId;
    _refreshPriorities();
    if (board.carriedPiece != null) onPiecePicked();
  }

  void pieceDragUpdate(int index, int pointerId, Vector2 delta) {
    if (!_owns(index, pointerId)) return;
    _touched();
    final wasCarried = board.carriedPiece != null;
    board.dragUpdate(ui.Offset(delta.x, delta.y));
    _refreshPriorities();
    // A tray piece is picked once the gesture turns out to be a drag.
    if (!wasCarried && board.carriedPiece != null) onPiecePicked();
  }

  void pieceDragEnd(int index, int pointerId) {
    if (!_owns(index, pointerId)) return;
    _pointer = null;
    final result = board.dragEnd();
    switch (result) {
      case DropResult.loose:
        _looseOrder[index] = ++_looseCounter;
      case DropResult.placed || DropResult.returnedToTray:
        _looseOrder.remove(index);
      case DropResult.none:
        break;
    }
    _refreshPriorities();
    if (session.isComplete) {
      _hint?.onComplete();
    } else if (result == DropResult.placed) {
      _hint?.onPiecePlaced();
    }
    _syncHand();
    onPieceDropped(result);
  }

  bool _owns(int index, int pointerId) =>
      board.grabbedPiece == index && _pointer == pointerId;

  void trayScrollUpdate(Vector2 delta) {
    _touched();
    if (board.grabbedPiece != null) return;
    board.scrollBy(delta.x * board.tray.axis.dx + delta.y * board.tray.axis.dy);
  }

  void _refreshPriorities() {
    final carried = board.carriedPiece;
    for (final piece in _pieces) {
      final i = piece.index;
      piece.priority = switch (session.pieces[i].status) {
        _ when i == carried => _carriedPriority,
        PieceStatus.placed => _placedPriority,
        PieceStatus.tray => _trayPriority,
        PieceStatus.loose => _loosePriority + (_looseOrder[i] ?? 0),
      };
    }
  }

  @override
  void onRemove() {
    _removed = true;
    for (final image in _pieceImages) {
      image.dispose();
    }
    super.onRemove();
  }
}
