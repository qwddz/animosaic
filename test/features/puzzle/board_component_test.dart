import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/game/board_component.dart';

void main() {
  testWidgets('board bakes shadow, fill and border once into an image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint());
      final source = recorder.endRecording().toImageSync(4, 4);
      final board = BoardComponent(
        rect: const ui.Rect.fromLTWH(10, 10, 300, 200),
        image: source,
        showHint: true,
      );
      expect(board.cachedImage, isNull);
      await board.onLoad();
      final cached = board.cachedImage!;
      expect(cached.width, greaterThanOrEqualTo(332));
      expect(cached.height, greaterThanOrEqualTo(232));
      // Rendering reuses the same image and does not rebuild it.
      board.render(ui.Canvas(ui.PictureRecorder()));
      expect(board.cachedImage, same(cached));
      board.onRemove();
      expect(board.cachedImage, isNull);
    });
  });

  testWidgets('the hint picture stays inside the rounded corners', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src);
      final source = recorder.endRecording().toImageSync(4, 4);
      final board = BoardComponent(
        rect: const ui.Rect.fromLTWH(0, 0, 300, 200),
        image: source,
        showHint: true,
      );
      await board.onLoad();
      final cached = board.cachedImage!;
      final scale = board.cachedScale;
      final bytes = (await cached.toByteData())!;
      int blueAt(double x, double y) {
        final px = (x * scale).floor();
        final py = (y * scale).floor();
        return bytes.getUint8((py * cached.width + px) * 4 + 2);
      }

      // One pixel inside the board's square corner, outside its
      // rounded one.
      final m = BoardComponent.margin;
      for (final (x, y) in [
        (m + 1, m + 1),
        (m + 299, m + 1),
        (m + 1, m + 199),
        (m + 299, m + 199),
      ]) {
        expect(blueAt(x, y), lessThan(30), reason: '($x, $y)');
      }
      // The middle shows the faded picture.
      expect(blueAt(m + 150, m + 100), greaterThan(60));
      board.onRemove();
      source.dispose();
    });
  });
}
