import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../app/book_palette.dart';
import '../domain/hand_hint_scheduler.dart';
import '../domain/hand_placement.dart';

/// Cartoon mitten that carries a see-through copy of a piece from where it
/// lies to its place on the board. The real piece stays put.
///
/// With reduced motion the hand stands still at the piece and a dashed
/// arrow points to the place. Has no event callbacks, so touches pass
/// straight through to the pieces and the tray.
class HandHintComponent extends Component {
  HandHintComponent({
    required this.target,
    required ui.Image pieceImage,
    required this.pieceSize,
    required double cellSide,
    required this.visible,
    required this.fromScale,
    required this.reducedMotion,
    required this.onFinished,
    super.priority,
  }) : handHeight = handHeightFor(cellSide),
       _image = pieceImage,
       _src = Rect.fromLTWH(
         0,
         0,
         pieceImage.width.toDouble(),
         pieceImage.height.toDouble(),
       ) {
    _buildHand();
    if (reducedMotion) _buildArrow();
  }

  /// Hand height for a piece whose shorter cell side is [cellSide].
  static double handHeightFor(double cellSide) =>
      (cellSide * 0.6).clamp(48.0, 140.0);

  final HintTarget target;
  final bool reducedMotion;

  /// Size of the piece at full scale on the board.
  final Size pieceSize;

  /// The whole hand stays inside this rect.
  final Rect visible;

  /// Height of the hand from fingertip to cuff.
  @visibleForTesting
  final double handHeight;

  /// Scale of the piece where it lies now (smaller in the tray).
  final double fromScale;

  /// Called once, after the last flight (or the static display) ends.
  final void Function() onFinished;

  final ui.Image _image;
  final Rect _src;

  // One flight: the hand appears on the piece, flies, then fades out.
  static const _appear = 0.3;
  static const _fly = 1.2;
  static const _fade = 0.4;
  static const _flight = _appear + _fly + _fade;

  /// How long the static hand stays with reduced motion.
  static const _staticDuration = 4.0;

  static const _ghostAlpha = 0.6;
  static const _staticGhostAlpha = 0.35;

  double get _duration => reducedMotion
      ? _staticDuration
      : _flight * HandHintScheduler.repeatsPerShow;

  double _time = 0;
  bool _finished = false;

  // Shapes in hand space, fingertip at the origin, [_baseHeight] tall.
  static final Path _baseMitten = Path.combine(
    PathOperation.union,
    Path()..addRRect(
      RRect.fromLTRBAndCorners(
        -17,
        0,
        17,
        46,
        topLeft: const Radius.circular(17),
        topRight: const Radius.circular(17),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
    ),
    Path()..addOval(const Rect.fromLTWH(-28, 15, 17, 25)),
  );
  static final Path _baseCuff = Path()
    ..addRRect(RRect.fromLTRBR(-19, 41, 19, 56, const Radius.circular(5)));
  static const _baseHeight = 56.0;

  static const _outlineWidth = 3.0;
  static const _shadowOffset = Offset(2, 4);

  // Built once per component, already scaled, tilted and mirrored.
  late final Path _mitten;
  late final Path _cuff;
  late final HandPlacement _placement;

  /// Bounds of the mirrored hand around its fingertip, with the outline.
  late final Rect _bounds;

  /// Tilt of the hand, so it reaches in from the lower right.
  static const _tilt = -0.45;

  final _skinPaint = Paint()..color = BookPalette.handSkin;
  final _cuffPaint = Paint()..color = BookPalette.primary;
  final _shadowPaint = Paint()..color = BookPalette.shadow;
  final _outlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _outlineWidth
    ..strokeJoin = StrokeJoin.round
    ..color = BookPalette.text;
  final _ghostPaint = Paint()..filterQuality = FilterQuality.medium;
  final _arrowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = BookPalette.text.withValues(alpha: 0.75);
  ui.Path? _arrow;

  @override
  void update(double dt) {
    _time += dt;
    if (!_finished && _time >= _duration) {
      _finished = true;
      onFinished();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_finished) return;
    if (reducedMotion) {
      _drawGhost(canvas, target.to, 1, _staticGhostAlpha);
      canvas.drawPath(_arrow!, _arrowPaint);
      _drawHand(canvas, target.from, fromScale, 1);
      return;
    }
    final t = _time % _flight;
    final Offset at;
    final double scale;
    final double alpha;
    if (t < _appear) {
      at = target.from;
      scale = fromScale;
      alpha = t / _appear;
    } else if (t < _appear + _fly) {
      final p = Curves.easeInOut.transform((t - _appear) / _fly);
      at = Offset.lerp(target.from, target.to, p)!;
      scale = fromScale + (1 - fromScale) * p;
      alpha = 1;
    } else {
      at = target.to;
      scale = 1;
      alpha = 1 - (t - _appear - _fly) / _fade;
    }
    _drawGhost(canvas, at, scale, _ghostAlpha * alpha);
    _drawHand(canvas, at, scale, alpha);
  }

  void _drawGhost(Canvas canvas, Offset center, double scale, double alpha) {
    _ghostPaint.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1));
    final dst = Rect.fromCenter(
      center: center,
      width: pieceSize.width * scale,
      height: pieceSize.height * scale,
    );
    canvas.drawImageRect(_image, _src, dst, _ghostPaint);
  }

  void _drawHand(Canvas canvas, Offset pieceCenter, double scale, double a) {
    final alpha = a.clamp(0.0, 1.0);
    _skinPaint.color = BookPalette.handSkin.withValues(alpha: alpha);
    _cuffPaint.color = BookPalette.primary.withValues(alpha: alpha);
    _outlinePaint.color = BookPalette.text.withValues(alpha: alpha);
    _shadowPaint.color = BookPalette.shadow.withValues(
      alpha: BookPalette.shadow.a * alpha,
    );
    final tip = _tipAt(pieceCenter, scale);
    canvas
      ..save()
      ..translate(tip.dx, tip.dy)
      ..save()
      ..translate(_shadowOffset.dx, _shadowOffset.dy)
      ..drawPath(_mitten, _shadowPaint)
      ..drawPath(_cuff, _shadowPaint)
      ..restore()
      ..drawPath(_mitten, _skinPaint)
      ..drawPath(_mitten, _outlinePaint)
      ..drawPath(_cuff, _cuffPaint)
      ..drawPath(_cuff, _outlinePaint)
      ..restore();
  }

  /// Fingertip slightly below and right of the piece centre (mirrored with
  /// the hand), so the piece stays visible.
  Offset _tipOffset(double scale) =>
      Offset(pieceSize.width * scale * 0.12, pieceSize.height * scale * 0.18);

  /// Where the fingertip goes, nudged so the hand stays inside [visible].
  Offset _tipAt(Offset pieceCenter, double scale) {
    final tip = pieceCenter + _placement.mirror(_tipOffset(scale));
    return tip + HandPlacement.nudge(_withShadow(_bounds.shift(tip)), visible);
  }

  /// Bounds of the drawn hand, shadow included, for a piece at
  /// [pieceCenter] shown at [scale].
  @visibleForTesting
  Rect handRectAt(Offset pieceCenter, double scale) =>
      _withShadow(_bounds.shift(_tipAt(pieceCenter, scale)));

  static Rect _withShadow(Rect r) => Rect.fromLTRB(
    r.left,
    r.top,
    r.right + _shadowOffset.dx,
    r.bottom + _shadowOffset.dy,
  );

  /// Scales and tilts the hand once and mirrors it away from the screen
  /// edges for the whole flight.
  void _buildHand() {
    final k = handHeight / _baseHeight;
    Float64List matrix({required bool flipX, required bool flipY}) {
      final c = cos(_tilt) * k;
      final s = sin(_tilt) * k;
      final fx = flipX ? -1.0 : 1.0;
      final fy = flipY ? -1.0 : 1.0;
      // Column-major 4x4: rotate by the tilt, scale by k, then mirror.
      return Float64List.fromList([
        fx * c, fy * s, 0, 0, //
        -fx * s, fy * c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);
    }

    final plain = matrix(flipX: false, flipY: false);
    final plainBounds = _baseMitten
        .transform(plain)
        .getBounds()
        .expandToInclude(_baseCuff.transform(plain).getBounds())
        .inflate(_outlineWidth / 2);
    _placement = HandPlacement.choose(
      visible: visible,
      stops: [
        for (final (centre, scale) in [
          (target.from, fromScale),
          (target.to, 1.0),
        ])
          (centre, _withShadow(plainBounds.shift(centre + _tipOffset(scale)))),
      ],
    );
    _bounds = _placement.apply(plainBounds, Offset.zero);
    final m = matrix(flipX: _placement.flipX, flipY: _placement.flipY);
    _mitten = _baseMitten.transform(m);
    _cuff = _baseCuff.transform(m);
  }

  /// Dashed line from the piece towards its place, with an arrow head.
  void _buildArrow() {
    final path = Path();
    final delta = target.to - target.from;
    final length = delta.distance;
    _arrow = path;
    if (length < 1) return;
    final dir = delta / length;
    final startGap = max(pieceSize.width, pieceSize.height) * fromScale * 0.5;
    const endGap = 10.0;
    const dash = 12.0;
    const gap = 9.0;
    final end = length - endGap;
    for (var d = startGap; d < end; d += dash + gap) {
      final a = target.from + dir * d;
      final b = target.from + dir * min(d + dash, end);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    if (end <= startGap) return;
    final tip = target.from + dir * end;
    const headLength = 16.0;
    const headAngle = 0.5;
    final back = Offset(-dir.dx, -dir.dy);
    for (final angle in const [headAngle, -headAngle]) {
      final c = cos(angle);
      final s = sin(angle);
      final wing = Offset(back.dx * c - back.dy * s, back.dx * s + back.dy * c);
      final p = tip + wing * headLength;
      path
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p.dx, p.dy);
    }
  }
}
