# Task completion

Run in order; all must be clean:
1. `flutter gen-l10n` (if any ARB changed).
2. `dart format lib test`
3. `flutter analyze` → must print "No issues found".
4. `flutter test`
5. For stage work: check the stage's «Готово, когда» criterion in `docs/PLAN.md`; UI/game changes also need a run on phone and tablet emulators.
Do not commit (no git).
