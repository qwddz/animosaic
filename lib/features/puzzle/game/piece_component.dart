import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'puzzle_game.dart';

class PieceComponent extends SpriteComponent
    with DragCallbacks, HasGameReference<PuzzleGame> {
  PieceComponent({
    required this.index,
    required ui.Image image,
    required this.outline,
    required super.size,
  }) : super(sprite: Sprite(image), anchor: Anchor.center);

  final int index;
  final ui.Path outline;

  /// How fast a piece glides to where the model wants it, per second.
  static const _followRate = 22.0;
  static const _liftedScale = 1.06;

  /// Jumps straight to the model state, skipping the glide.
  void syncInstantly() {
    final board = game.board;
    final target = board.positions[index];
    position.setValues(target.dx, target.dy);
    scale.setAll(board.scales[index]);
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      game.board.isDraggable(index) &&
      outline.contains(ui.Offset(point.x, point.y));

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.pieceDragStart(index, event.pointerId);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.pieceDragUpdate(index, event.pointerId, event.canvasDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.pieceDragEnd(index, event.pointerId);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final board = game.board;
    final target = board.positions[index];
    final carried = board.carriedPiece == index;
    final targetScale = board.scales[index] * (carried ? _liftedScale : 1);
    final t = min(1.0, dt * _followRate);
    if (carried) {
      position.setValues(target.dx, target.dy);
    } else {
      position.x += (target.dx - position.x) * t;
      position.y += (target.dy - position.y) * t;
    }
    scale.setAll(scale.x + (targetScale - scale.x) * t);
  }
}
