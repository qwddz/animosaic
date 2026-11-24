# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Animal jigsaw puzzle game for kids: Flutter + Flame, Android first, landscape only, phones and tablets. The product plan, stages and acceptance criteria live in `docs/PLAN.md` (Russian). Work one stage at a time and check the stage's «Готово, когда» criterion before moving on.

Android is the only platform: the `ios/`, `macos/`, `linux/`, `windows/` and `web/` folders were removed. Bring one back with `flutter create --platforms=<name> .` when needed.

Git repo: `origin` is git@github.com:qwddz/animosaic.git (SSH), branch `main`. Commit or push only when asked; no GitHub CI for now.

## Commands

```bash
flutter pub get                                   # install dependencies
flutter gen-l10n                                  # regenerate lib/l10n/app_localizations*.dart from ARB files
flutter analyze                                   # must report "No issues found"
dart format lib test                              # format
flutter test                                      # all tests
flutter test test/app/locale_test.dart            # one file
flutter test --plain-name "falls back to English" # one test by name
flutter emulators --launch Medium_Phone_API_37.0  # phone emulator (20:9)
flutter emulators --launch Tablet_API_37          # tablet emulator (2560x1600, 16:10)
flutter run -d <device-id>                        # run on a device from `flutter devices`
flutter run -d <device-id> --dart-define=CDN_BASE_URL=https://cdn.animosaic.app  # with paid pictures from the CDN
flutter run -d <device-id> --dart-define=CDN_BASE_URL=https://cdn.animosaic.app --dart-define=REVENUECAT_API_KEY=$REVENUECAT_GOOGLE_API_KEY  # real Google Play purchases (value from .env)
flutter run --profile -d <device-id>              # FPS / performance checks
```

## Release build

The upload key lives outside the project folder. Create it once:

```bash
mkdir -p ~/keys/puzzles
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v -keystore ~/keys/puzzles/upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then write `~/keys/puzzles/key.properties` with `storeFile=/Users/<you>/keys/puzzles/upload.jks`, `storePassword=…`, `keyAlias=upload` and `keyPassword=…`. Build with:

```bash
PUZZLES_KEY_PROPERTIES=~/keys/puzzles/key.properties flutter build appbundle --release \
  --build-number=$(date -u +%y%m%d%H) \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=CDN_BASE_URL=https://cdn.animosaic.app \
  --dart-define=REVENUECAT_API_KEY=$(grep '^REVENUECAT_GOOGLE_API_KEY=' .env | cut -d= -f2-) \
  --dart-define=REVIEW_CODE_SHA256=$(grep '^REVIEW_CODE=' .env | cut -d= -f2- | tr -cd 'A-Z0-9' | shasum -a 256 | cut -c1-64)
```

The AAB lands in `build/app/outputs/bundle/release/app-release.aab` (~83 MB with all three ABIs; Play serves one ABI, about 38 MB download on an arm64 phone).

- `versionCode` must grow with every Play upload, or Play rejects the bundle. `--build-number` overrides the `+1` in `pubspec.yaml`; the UTC date and hour (`26111313`) always grows and stays under Play's 2100000000 limit. Two uploads in the same hour need a manual bump. `versionName` still comes from `version:` in `pubspec.yaml`.
- `--obfuscate` renames Dart symbols. Stack traces from that build can only be read with the matching `build/symbols/app.android-*.symbols`: copy `build/symbols` aside for every uploaded build (e.g. `~/keys/puzzles/symbols/<build-number>/`), `flutter clean` deletes it. Decode with `flutter symbolize -i <trace.txt> -d build/symbols/app.android-arm64.symbols`.
- R8 (`isMinifyEnabled`, `isShrinkResources`) is on in `android/app/build.gradle.kts`. The Java mapping (`build/app/outputs/mapping/release/mapping.txt`) and native debug symbols are packed into the AAB, so Play Console deobfuscates Java/native crashes by itself. No `proguard-rules.pro` is needed: Flutter and the plugins (RevenueCat, audioplayers) ship their own rules. If a release build crashes with `ClassNotFoundException` / `NoSuchMethodError` and debug does not, add the missing `-keep` rule in `android/app/proguard-rules.pro` (Flutter picks it up automatically).
- Google Play reviewers can't buy, so the paywall has "I have an access code" (`lib/features/purchase/data/review_access.dart`). The code is `REVIEW_CODE` in `.env`; only its sha256 goes into the build (`REVIEW_CODE_SHA256`), and without it the button is hidden. Play Console → App content → App access holds the code and the steps: locked picture → parental gate → "I have an access code". A new code locks devices that used the old one.
- To check a release build on an emulator, build `flutter build apk --release` with the same flags and `adb install` it. The release key differs from the debug key, so uninstall the debug app first (this wipes its progress).

A release build without `CDN_BASE_URL` or `REVENUECAT_API_KEY` stops at startup: paid pictures would be unreachable or unbuyable. Without `REVENUECAT_API_KEY`, debug builds and tests use the fake "test store" (`FakePurchaseService`, instant purchase, nothing charged); the RevenueCat SDK is never configured then. The key is RevenueCat's public Android SDK key. The CDN is the Cloudflare R2 bucket `puzzles` (EU) served at `cdn.animosaic.app` (domain registered at Cloudflare). Manifest URLs are relative, so moving the CDN only changes this define. Content is published with `tools/image_pipeline/upload.py`.

Without `PUZZLES_KEY_PROPERTIES`, release builds are signed with the debug key, and Google Play rejects those. Flutter's final symbol-strip check needs the Android SDK `cmdline-tools` component; install it from Android Studio → SDK Manager → SDK Tools. Without it the build prints "failed to strip debug symbols" and exits non-zero, but the AAB is already written and its native libraries are stripped (AGP does that); the message is only Flutter's check failing.

## Architecture

- `lib/main.dart` locks orientation to landscape and wraps the app in `ProviderScope`.
- `lib/app/` — `PuzzlesApp` (`MaterialApp.router`), `routerProvider` (go_router, exposed through Riverpod), theme, and `resolveAppLocale` (first supported device language, else English).
- `lib/features/<feature>/` — one folder per feature from the plan: `catalog`, `puzzle`, `progress`, `purchase`, `content`, `settings`. `lib/core/` holds shared constants and utilities.
- Menus, catalog, paywall and settings are plain Flutter widgets; Flame is used only on the puzzle screen via `GameWidget` (bridge with `flame_riverpod`).
- Puzzle slicing (piece shapes from grid + seed, target positions) is pure Dart with no Flame imports, so it is unit-tested.
- Puzzle screen layers, `lib/features/puzzle/`:
  - `domain/` is pure Dart: `PuzzleCut` and `PieceGeometry` cut the picture, `PuzzleLayout` and `TrayGeometry` place the board and tray, `PuzzleSession` is the saveable state, and `PuzzleBoard` holds the interaction rules (tray scroll vs pick, snapping, loose pieces). A tray gesture scrolls only when it runs at least twice as much along the tray as across it (`scrollBias`) and the tray can scroll; anything else picks the piece. A piece resting in the tray is grabbed anywhere on its slot square (`hitsTraySlot`), elsewhere only inside its outline. `test/features/puzzle/puzzle_board_test.dart` solves every difficulty on several screen sizes through `PuzzleBoard`.
  - `game/` is Flame: components only follow `board.positions` and `board.scales` and forward drags. Pieces are pre-rendered to images.
  - `PuzzleController`, a Riverpod family keyed by puzzle and difficulty, owns loading, saving after each drop, completion and restart. It also records progress. `PuzzleScreen` only renders it and recreates the game when the session object, the size or the hint setting changes.
- Progress (`progressProvider`, the best difficulty per picture) and the unfinished puzzle live in JSON files written through `core/json_file_store.dart`. Settings (`settingsProvider`: sound, music, hint, language) live in SharedPreferences, which are loaded in `main()` before the first frame.
- Routes: `/` categories, `/category/:id` pictures, `/puzzle/:id?difficulty=` the game, `/paywall?from=<puzzleId>&difficulty=` the full version (opens `from` after the purchase, else goes back), `/settings`.
- Full version (`lib/features/purchase/`): `PurchaseService` with RevenueCat (entitlement `full`, offering `default`) and fake implementations; `fullAccessProvider` follows purchases, restores and refunds. Every access check goes through `canPlay` / `canPlayProvider(entry)` (`entry.free || fullAccess`): locked catalog cards (blurred thumb + lock → parental gate → paywall), the `/puzzle/:id` redirect to the paywall, `PuzzleController` (throws `PuzzleLockedException`) and the win overlay's "Next" (`nextPlayableProvider` skips locked pictures, so a child is never sent to the paywall from the game).
- Content comes from `assets/manifest.json` (`ContentManifest`), replaced at runtime by a newer valid `manifest.json` from the CDN (`lib/features/content/`). The 55 free pictures live in `assets/images/free/`, previews of all 297 in `assets/thumbs/`; the 242 paid pictures are downloaded from the CDN on first open, checked by sha256 and cached in the app support folder (`PictureStore`). Every manifest entry also carries CDN fields, so builds that lack a bundled file fall back to the CDN.
- Pictures are made by `tools/image_pipeline/` (Python, `uv`): Nano Banana 2 Lite with the anchor `docs/puzzle_refs/style_anchor.png`, rows in `animals.csv`, style in `docs/puzzle_refs/STYLE.md`. `manifest.py` writes `assets/manifest.json`; don't edit the manifest's picture entries by hand. See its README for the generate → review → process → manifest cycle; generation costs money, so always pass `--budget`.

## Rules

- State lives in Riverpod providers; widgets render and forward events, no business logic in widgets.
- No user-facing strings in code: every string goes into `lib/l10n/app_en.arb` (template) plus `app_uk.arb` and `app_ru.arb`, then `flutter gen-l10n`. Content titles (categories, animals) come from the content manifest, keyed by id.
- Tests are required for puzzle slicing and progress storage.
- Android: the activity is `sensorLandscape` and the application declares `android:appCategory="game"` (keeps landscape on Android 16+ large screens). Keep both when editing `AndroidManifest.xml`.
- RevenueCat project `animosaic.app` (`proj99823e63`): entitlement `full` (the only one the app checks) ← products `full_version` (Google Play app `app.animosaic.puzzles`) and `lifetime` (Test Store); offering `default` (current) with package `$rc_lifetime`. Keys in `.env`: `REVENUECAT_GOOGLE_API_KEY` (goog_, release builds), `REVENUECAT_API_KEY` (test_, Test Store for debug), `REVENUECAT_SECRET_KEY` (sk_, API v2 for configuration only — never pass it to a build). The auto-created entitlement `animosaic_app_pro` is unused.
- `applicationId` and `namespace` are `app.animosaic.puzzles` (`MainActivity` in `android/app/src/main/kotlin/app/animosaic/puzzles/`). Play Console ties the app and the `full_version` product to this id, so don't change it.
- The Android launcher name is not in ARB: it lives in `android/app/src/main/res/values{,-uk,-ru}/strings.xml` (`app_name`).
- The release keystore and `key.properties` live outside the project folder and are found through `PUZZLES_KEY_PROPERTIES`; see "Release build".
- API keys (image generator, RevenueCat, CDN) only via environment variables or `.env`, never in code or assets.
