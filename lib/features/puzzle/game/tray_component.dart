import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../../app/book_palette.dart';
import 'puzzle_game.dart';

/// Tray background. Dragging on free space scrolls the tray.
class TrayComponent extends PositionComponent
    with DragCallbacks, HasGameReference<PuzzleGame> {
  TrayComponent({required Rect rect})
    : super(
        position: Vector2(rect.left, rect.top),
        size: Vector2(rect.width, rect.height),
      );

  static const _radius = Radius.circular(12);
  final _fill = Paint()..color = BookPalette.card.withValues(alpha: 0.7);
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = BookPalette.outline;

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(size.toRect(), _radius);
    canvas
      ..drawRRect(rrect, _fill)
      ..drawRRect(rrect, _stroke);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.trayScrollUpdate(event.canvasDelta);
  }
}
