import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/hand_hint_scheduler.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_layout.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_session.dart';
import 'package:puzzles/features/puzzle/game/hand_hint_component.dart';
import 'package:puzzles/features/puzzle/game/puzzle_game.dart';

void main() {
  const size = Size(915, 411);

  Future<PuzzleGame> pumpGame(
    WidgetTester tester, {
    required bool handHint,
    bool firstPuzzle = true,
    bool reducedMotion = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final image = (await tester.runAsync(() {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFF88AA66), BlendMode.src);
      return recorder.endRecording().toImage(64, 64);
    }))!;
    addTearDown(image.dispose);
    final game = PuzzleGame(
      image: image,
      session: PuzzleSession.start(
        puzzleId: 'p',
        difficulty: Difficulty.easy,
        seed: 3,
      ),
      layout: PuzzleLayout.compute(size),
      pixelRatio: 1,
      showHint: false,
      handHint: handHint,
      firstPuzzle: firstPuzzle,
      reducedMotion: reducedMotion,
      onPiecePicked: () {},
      onPieceDropped: (_) {},
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(() async => game.toBeLoaded());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  Iterable<HandHintComponent> hands(PuzzleGame game) =>
      game.children.whereType<HandHintComponent>();

  testWidgets('setting off: no hand at all', (tester) async {
    final game = await pumpGame(tester, handHint: false);
    expect(game.board.session.pieces, isNotEmpty);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 16));
    expect(hands(game), isEmpty);
  });

  testWidgets('first puzzle: hand at once, a touch removes it', (tester) async {
    final game = await pumpGame(tester, handHint: true);
    expect(hands(game), hasLength(1));
    expect(hands(game).single.reducedMotion, isFalse);

    game.touchDown();
    await tester.pump(const Duration(milliseconds: 16));
    expect(hands(game), isEmpty);

    // A finger held down keeps the hand away.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 16));
    expect(hands(game), isEmpty);

    game.touchUp();
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(hands(game), hasLength(1));
  });

  testWidgets('not the first puzzle: no hand at the start', (tester) async {
    final game = await pumpGame(tester, handHint: true, firstPuzzle: false);
    expect(hands(game), isEmpty);
  });

  testWidgets('reduced motion: static hand', (tester) async {
    final game = await pumpGame(tester, handHint: true, reducedMotion: true);
    expect(hands(game).single.reducedMotion, isTrue);
  });

  testWidgets('the hand grows with the piece, within limits', (tester) async {
    expect(HandHintComponent.handHeightFor(40), 48);
    expect(HandHintComponent.handHeightFor(120), closeTo(72, 0.01));
    expect(HandHintComponent.handHeightFor(400), 140);

    final game = await pumpGame(tester, handHint: true);
    final hand = hands(game).single;
    final cell = game.board.geometry;
    expect(
      hand.handHeight,
      HandHintComponent.handHeightFor(
        cell.cellWidth < cell.cellHeight ? cell.cellWidth : cell.cellHeight,
      ),
    );
  });

  testWidgets('the hand stays on screen next to the edges', (tester) async {
    final image = (await tester.runAsync(() {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFF88AA66), BlendMode.src);
      return recorder.endRecording().toImage(8, 8);
    }))!;
    addTearDown(image.dispose);
    const visible = Rect.fromLTWH(0, 0, 915, 411);
    for (final to in const [
      Offset(300, 380),
      Offset(890, 200),
      Offset(890, 395),
      Offset(20, 20),
    ]) {
      final hand = HandHintComponent(
        target: HintTarget(index: 0, from: const Offset(700, 150), to: to),
        pieceImage: image,
        pieceSize: const Size(160, 160),
        cellSide: 120,
        visible: visible,
        fromScale: 0.6,
        reducedMotion: false,
        onFinished: () {},
      );
      for (final (at, scale) in [(const Offset(700, 150), 0.6), (to, 1.0)]) {
        final rect = hand.handRectAt(at, scale);
        expect(rect.left, greaterThanOrEqualTo(visible.left), reason: '$to');
        expect(rect.top, greaterThanOrEqualTo(visible.top), reason: '$to');
        expect(rect.right, lessThanOrEqualTo(visible.right), reason: '$to');
        expect(rect.bottom, lessThanOrEqualTo(visible.bottom), reason: '$to');
      }
    }
  });
}
