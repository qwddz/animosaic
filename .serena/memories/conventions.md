# Conventions

- Riverpod 3 hand-written: `AsyncNotifierProvider<X, T>(X.new)` / `Notifier`; controllers named `*Controller`, providers `*Provider`. Families keyed by Dart records (e.g. `PuzzleArgs = ({String puzzleId, Difficulty difficulty})`).
- Dependencies injected via small providers (e.g. `progressStoreProvider`, `sessionRepositoryProvider`) so tests override them with temp-dir `JsonFileStore`s in a `ProviderContainer`.
- Persistence pattern (`ProgressController`): writes serialized through a `_lastWrite` future chain; if the file exists but fails to parse, keep state in memory and never overwrite (`_canWrite = false`). Domain models expose `fromJson` returning null on bad data and `toJson`.
- Domain classes are immutable; updates return new instances (return `identical` instance when unchanged).
- Widgets only render and forward events; logic lives in controllers or pure-Dart domain.
- Pure-Dart `domain/` must not import Flame or Flutter UI — keeps it unit-testable.
- Strings: none hard-coded in UI; add to all three ARB files. Content titles come from manifest keyed by id. Android launcher name lives in `res/values{,-uk,-ru}/strings.xml`.
- Doc comments `///` on non-obvious behavior only; terse.
- Tests required for slicing and progress storage; `puzzle_board_test.dart` solves every difficulty on several screen sizes.
