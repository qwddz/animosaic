import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/settings_controller.dart';

/// Remembers that the child has placed a piece in some puzzle, so the hand
/// no longer shows at once at the start of a puzzle.
class FirstPuzzleStore {
  FirstPuzzleStore(this._prefs);

  static const _key = 'hint.firstPuzzleDone';

  final SharedPreferences _prefs;

  /// Children who already have progress (an update from an earlier version)
  /// count as done.
  bool isDone(bool hasProgress) =>
      hasProgress || (_prefs.getBool(_key) ?? false);

  Future<void> markDone() => _prefs.setBool(_key, true);
}

final firstPuzzleStoreProvider = Provider<FirstPuzzleStore>(
  (ref) => FirstPuzzleStore(ref.read(sharedPreferencesProvider)),
);
