# Core

Kids' animal jigsaw game, Flutter + Flame, Android first, landscape only. Root `CLAUDE.md` is the authoritative rules/architecture doc; `docs/PLAN.md` (Russian) holds stages 0–7 with «Готово, когда» acceptance criteria — work one stage at a time.

## Source map
- `lib/main.dart` — landscape lock, SharedPreferences preload, `ProviderScope`.
- `lib/app/` — `PuzzlesApp`, `routerProvider` (go_router), theme, `resolveAppLocale`.
- `lib/core/json_file_store.dart` — `JsonFileStore(dirGetter, fileName)`; used for progress and unfinished session.
- `lib/features/catalog/` — categories/pictures screens, difficulty dialog, `ContentManifest` from `assets/manifest.json`.
- `lib/features/puzzle/` — `domain/` pure Dart (cut, geometry, layout, tray, session, `PuzzleBoard` rules), `game/` Flame components (follow `board.positions`/`board.scales` only), `data/` session repo + setup, `PuzzleController` (family keyed by `PuzzleArgs` record `(puzzleId, difficulty)`).
- `lib/features/progress/` — `progressProvider` (`AsyncNotifier`), best difficulty per picture.
- `lib/features/settings/` — `settingsProvider` (sound, music, hint, language) on SharedPreferences.
- `lib/features/content/` — CDN delivery: `cdnBaseUrlProvider` (`--dart-define=CDN_BASE_URL`, release fails without it), `ManifestSource` (bundled vs cached vs remote manifest, sanity-checked), `PictureStore` (bundled asset or sha256-verified CDN download cached in app support `pictures/`). CDN = Cloudflare R2 bucket `puzzles` (EU) at `https://cdn.animosaic.app`.
- `lib/features/purchase/` — full version: `PurchaseService` (RevenueCat / fake), `fullAccessProvider`, `canPlay`/`canPlayProvider`.
- `lib/features/audio/` — sound and music.
- `tools/image_pipeline/` — Python (uv) picture pipeline: generate.py (Gemini, paid — always `--budget`), review.py, process.py, manifest.py (owns picture entries in `assets/manifest.json`). 297 pictures: 55 free bundled as WebP, paid ones in `processed/` for the CDN.
- `test/` mirrors `lib/`.

## Invariants
- Git: origin github.com/qwddz/animosaic, branch main; commit/push only when asked.
- Flame only on puzzle screen; everything else plain widgets.
- Never `Read`/`Edit` generated `lib/l10n/app_localizations*.dart`; edit ARB files and run `flutter gen-l10n`.

Further: stack/versions `mem:tech_stack`; code patterns (Riverpod, persistence, l10n) `mem:conventions`; commands `mem:suggested_commands`; done-checklist `mem:task_completion`.
