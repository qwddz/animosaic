import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../app/book_palette.dart';

/// The frame where pieces are assembled, with an optional faded picture.
class BoardComponent extends PositionComponent {
  BoardComponent({
    required Rect rect,
    required this.image,
    required this.showHint,
  }) : super(
         position: Vector2(rect.left, rect.top),
         size: Vector2(rect.width, rect.height),
       );

  final ui.Image image;
  final bool showHint;

  static const _radius = Radius.circular(12);
  final _fill = Paint()..color = BookPalette.card;
  final _shadow = Paint()
    ..color = BookPalette.shadow
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  final _hint = Paint()
    ..color = const Color(0x52FFFFFF)
    ..filterQuality = FilterQuality.medium;
  final _blit = Paint()..filterQuality = FilterQuality.medium;
  final _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = BookPalette.outline;

  /// Shadow, fill, hint and border baked into one image, so the blurred
  /// shadow is not repainted every frame. Null until [onLoad].
  @visibleForTesting
  ui.Image? get cachedImage => _cached;
  ui.Image? _cached;
  double _scale = 1;

  /// Device pixels per logical pixel in [cachedImage].
  @visibleForTesting
  double get cachedScale => _scale;

  /// Room around the board for the shadow's offset (4) and blur (3 sigma).
  @visibleForTesting
  static const margin = 20.0;

  @override
  Future<void> onLoad() async {
    final views = ui.PlatformDispatcher.instance.views;
    _scale = views.isEmpty ? 1 : views.first.devicePixelRatio;
    final rect = size.toRect();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(_scale)
      ..translate(margin, margin);
    _paintBoard(canvas, rect);
    final picture = recorder.endRecording();
    _cached = picture.toImageSync(
      ((rect.width + 2 * margin) * _scale).ceil(),
      ((rect.height + 2 * margin) * _scale).ceil(),
    );
    picture.dispose();
  }

  @override
  void onRemove() {
    _cached?.dispose();
    _cached = null;
    super.onRemove();
  }

  void _paintBoard(Canvas canvas, Rect rect) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect.shift(const Offset(0, 4)), _radius),
        _shadow,
      )
      ..drawRRect(RRect.fromRectAndRadius(rect, _radius), _fill);
    if (showHint) {
      // The square picture would poke out of the rounded corners.
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(rect, _radius))
        ..drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          rect,
          _hint,
        )
        ..restore();
    }
    canvas.drawRRect(RRect.fromRectAndRadius(rect, _radius), _border);
  }

  @override
  void render(Canvas canvas) {
    final cached = _cached;
    if (cached == null) return;
    // The image was rounded up to whole device pixels; take exactly the
    // painted part, so it lands on the logical rect without stretching.
    final logical = Rect.fromLTWH(
      -margin,
      -margin,
      size.x + 2 * margin,
      size.y + 2 * margin,
    );
    canvas.drawImageRect(
      cached,
      Rect.fromLTWH(0, 0, logical.width * _scale, logical.height * _scale),
      logical,
      _blit,
    );
  }
}
