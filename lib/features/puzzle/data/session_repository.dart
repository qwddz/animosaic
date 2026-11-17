import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/json_file_store.dart';
import '../domain/difficulty.dart';
import '../domain/puzzle_session.dart';

/// Keeps one unfinished puzzle on disk so it survives the app being killed.
class SessionRepository {
  SessionRepository(Future<Directory> Function() directory)
    : _store = JsonFileStore(directory, 'unfinished_puzzle.json');

  final JsonFileStore _store;

  /// The saved session if it belongs to this puzzle and difficulty.
  Future<PuzzleSession?> load(String puzzleId, Difficulty difficulty) async {
    final session = PuzzleSession.fromJson(await _store.read());
    if (session == null ||
        session.puzzleId != puzzleId ||
        session.difficulty != difficulty ||
        session.isComplete) {
      return null;
    }
    return session;
  }

  Future<void> save(PuzzleSession session) => _store.write(session.toJson());

  Future<void> clear() => _store.delete();
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(getApplicationSupportDirectory),
);
