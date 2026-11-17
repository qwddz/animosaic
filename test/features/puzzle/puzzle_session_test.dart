import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_session.dart';

void main() {
  PuzzleSession start() => PuzzleSession.start(
    puzzleId: 'sea_turtle',
    difficulty: Difficulty.medium,
    seed: 5,
  );

  test('starts with every piece in the tray in shuffled order', () {
    final session = start();
    expect(session.pieces.every((p) => p.status == PieceStatus.tray), isTrue);
    expect(session.trayOrder.toSet(), Set.of(List.generate(12, (i) => i)));
    expect(session.trayOrder, isNot(List.generate(12, (i) => i)));
    expect(start().trayOrder, session.trayOrder);
  });

  test('completes when every piece is placed', () {
    final session = start();
    for (var i = 0; i < 12; i++) {
      expect(session.isComplete, isFalse);
      session.place(i);
    }
    expect(session.isComplete, isTrue);
    expect(session.trayOrder, isEmpty);
  });

  test('loose and returned pieces update the tray', () {
    final session = start();
    final first = session.trayOrder.first;
    session.moveLoose(first, const Offset(0.5, 0.25));
    expect(session.trayOrder, isNot(contains(first)));
    session.returnToTray(first);
    expect(session.trayOrder.first, first);
    expect(session.pieces[first].status, PieceStatus.tray);
  });

  test('survives a JSON round trip', () {
    final session = start()
      ..place(3)
      ..moveLoose(7, const Offset(1.2, 0.4));
    final restored = PuzzleSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())),
    )!;
    expect(restored.puzzleId, 'sea_turtle');
    expect(restored.difficulty, Difficulty.medium);
    expect(restored.seed, 5);
    expect(restored.pieces[3].status, PieceStatus.placed);
    expect(restored.pieces[7].loose, const Offset(1.2, 0.4));
    expect(restored.trayOrder, session.trayOrder);
  });

  test('rejects inconsistent data', () {
    final json = start().toJson();
    expect(PuzzleSession.fromJson({...json, 'difficulty': 'giant'}), isNull);
    expect(
      PuzzleSession.fromJson({
        ...json,
        'trayOrder': [0, 1],
      }),
      isNull,
    );
    expect(PuzzleSession.fromJson({...json, 'version': 99}), isNull);
    expect(PuzzleSession.fromJson('nonsense'), isNull);
  });
}
