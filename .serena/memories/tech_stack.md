# Tech stack

- Dart SDK `^3.13.5`, Flutter (stable), lints: `flutter_lints ^6` (default rules, platform dirs excluded).
- Game: `flame ^1.38`, `flame_audio`, `flame_riverpod ^5`.
- State: `flutter_riverpod ^3` — no codegen (`riverpod_generator` not used); providers declared by hand.
- Routing: `go_router ^18`.
- Storage: `shared_preferences` (settings), `path_provider` + JSON files (progress, session).
- Planned stages: `dio` + `crypto` (CDN content, sha256), `purchases_flutter` (RevenueCat, entitlement `plus`).
- l10n: `flutter_localizations` + `intl`, `gen-l10n` (`l10n.yaml`: template `app_en.arb`, `nullable-getter: false`), locales en/uk/ru.
- Emulators: `Medium_Phone_API_37.0` (20:9), `Tablet_API_37` (16:10).
