# Suggested commands

```bash
flutter pub get
flutter gen-l10n                                   # after any ARB change
flutter analyze
dart format lib test
flutter test                                       # all
flutter test test/features/puzzle/puzzle_board_test.dart
flutter test --plain-name "<test name>"
flutter emulators --launch Medium_Phone_API_37.0
flutter emulators --launch Tablet_API_37
flutter devices && flutter run -d <id>
flutter run --profile -d <id>                      # FPS checks (48 pieces @ 60 FPS target)
PUZZLES_KEY_PROPERTIES=~/keys/puzzles/key.properties flutter build appbundle --release
```

Darwin: BSD `sed -i ''` (needs empty suffix), BSD `find`/`grep` (no `-P` in grep). No git in this project.
