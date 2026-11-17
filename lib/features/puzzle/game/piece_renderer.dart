import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../domain/piece_geometry.dart';

/// Draws one piece into its own image once, so frames only blit sprites.
Future<ui.Image> renderPiece({
  required ui.Image source,
  required PieceGeometry geometry,
  required int index,
  required double pixelRatio,
}) async {
  final size = geometry.pieceSize;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  final outline = geometry.piecePath(index);

  final box = geometry.pieceBox(index);
  final visible = box.intersect(Offset.zero & geometry.boardSize);
  final sx = source.width / geometry.boardSize.width;
  final sy = source.height / geometry.boardSize.height;
  final src = Rect.fromLTRB(
    visible.left * sx,
    visible.top * sy,
    visible.right * sx,
    visible.bottom * sy,
  );

  canvas
    ..save()
    ..clipPath(outline)
    ..drawImageRect(
      source,
      src,
      visible.shift(-box.topLeft),
      Paint()..filterQuality = FilterQuality.medium,
    )
    ..restore()
    ..drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x99FFFFFF),
    );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * pixelRatio).ceil(),
    (size.height * pixelRatio).ceil(),
  );
  picture.dispose();
  return image;
}
