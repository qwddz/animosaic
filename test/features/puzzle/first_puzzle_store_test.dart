import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/data/first_puzzle_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<FirstPuzzleStore> store([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return FirstPuzzleStore(await SharedPreferences.getInstance());
  }

  test('fresh install: first puzzle not done', () async {
    expect((await store()).isDone(false), isFalse);
  });

  test('existing progress counts as first puzzle done', () async {
    expect((await store()).isDone(true), isTrue);
  });

  test('flag persists', () async {
    await (await store()).markDone();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hint.firstPuzzleDone'), isTrue);
    expect(FirstPuzzleStore(prefs).isDone(false), isTrue);
  });

  test('reads a flag stored by an earlier launch', () async {
    expect((await store({'hint.firstPuzzleDone': true})).isDone(false), isTrue);
  });
}
