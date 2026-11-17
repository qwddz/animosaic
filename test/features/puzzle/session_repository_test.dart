import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/data/session_repository.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_session.dart';

void main() {
  late Directory dir;
  late SessionRepository repository;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('puzzle_sessions');
    repository = SessionRepository(() async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PuzzleSession session() => PuzzleSession.start(
    puzzleId: 'farm_pig',
    difficulty: Difficulty.hard,
    seed: 9,
  )..place(2);

  test('loads what was saved for the same puzzle and difficulty', () async {
    await repository.save(session());
    final loaded = await repository.load('farm_pig', Difficulty.hard);
    expect(loaded?.pieces[2].status, PieceStatus.placed);
  });

  test('ignores a save for another puzzle or difficulty', () async {
    await repository.save(session());
    expect(await repository.load('sea_turtle', Difficulty.hard), isNull);
    expect(await repository.load('farm_pig', Difficulty.easy), isNull);
  });

  test('clear removes the save, corrupt files are ignored', () async {
    await repository.save(session());
    await repository.clear();
    expect(await repository.load('farm_pig', Difficulty.hard), isNull);
    File('${dir.path}/unfinished_puzzle.json').writeAsStringSync('{oops');
    expect(await repository.load('farm_pig', Difficulty.hard), isNull);
  });
}
