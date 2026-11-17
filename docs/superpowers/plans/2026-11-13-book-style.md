# «Бумага и акварель» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle every screen of Animosaic as a cozy picture book (cream paper, passe-partout cards, Nunito, three button kinds), add the hand hint that shows how to drag a piece, and rename categories in ru/uk/en.

**Architecture:** One palette + theme module feeds both Flutter widgets and Flame components. A small set of shared book widgets (background, buttons, card, dialog) replaces Material defaults screen by screen. The hand hint is a pure-Dart scheduler (testable timing) driving a Flame overlay component. Category names change only in the content pipeline and reach installed builds through the CDN manifest.

**Tech Stack:** Flutter, Flame, Riverpod 3 (hand-written providers), go_router, SharedPreferences, Python pipeline (`tools/image_pipeline`).

**Spec:** `docs/superpowers/specs/2026-11-13-book-style-design.md`

## Global Constraints

- No git in this project: skip every commit step; instead finish each task with `dart format lib test`, `flutter analyze` → "No issues found!", `flutter test` → all pass.
- CLAUDE.md rules: state in Riverpod providers, no business logic in widgets, every user-facing string in `lib/l10n/app_en.arb` + `app_uk.arb` + `app_ru.arb` then `flutter gen-l10n`.
- Palette (spec «Цвета»): paper gradient #FFF8EA → #F6EAD3 → #EFDCC0; passe-partout #FFFDF8; text #4A3628; secondary text #7A6250 (contrast ≥ 4.5:1 on #FFFDF8, else darken); primary button #E07B52 with step #B65A37 and white text; secondary #FFFDF8 with step #E2CFAE; text button #B65A37; stars #E2A33B; tray outline/dividers #ECDCC2; shadows warm ≈ rgba(120,80,40,.18).
- Font: Nunito bundled as an asset (OFL, licence file alongside), weights 700 body / 800 headings (600 allowed for long text); never fetched at runtime.
- Light theme only.
- Touch targets ≥ 48 dp; tilting cards must not shift hit areas.
- Hand hint rules (spec «Рука-подсказка» + decisions): only if «Подсказки рукой» is on (default on); first puzzle ever → shown at once; otherwise after 8 s idle; any touch restarts the countdown and hides the hand; each next show in the same puzzle waits double (8 → 16 → 32 s…); a correctly placed piece resets the wait to 8 s; 2 repeats per show; reduced motion → static hand at the piece + dashed arrow to the target; users who already have progress count as «first puzzle done».
- Win overlay buttons: «Дальше» primary, «Ещё раз» secondary, «Назад» text; with no next picture «Ещё раз» is primary.
- Category names (exact):

| id | ru | uk | en |
|---|---|---|---|
| sea | Морские жители | Морські мешканці | Sea friends |
| farm | На ферме | На фермі | On the farm |
| pets | Питомцы | Улюбленці | Pets |
| jungle | В джунглях | У джунглях | In the jungle |
| savanna | В саванне | У савані | On the savanna |
| desert | В пустыне | У пустелі | In the desert |
| spiders | Паучки | Павучки | Little spiders |
| sharks | Акулы | Акули | Sharks |
| snakes | Змейки | Змійки | Snakes |
| felines | Котики | Котики | Cats big and small |
| canines | Собачья семейка | Собача родина | Dog family |

## Review Focus

1. Long names in narrow cards (uk «Морські мешканці», en «Cats big and small») on a 360 dp phone with 3 columns → caption must ellipsize, counter must stay visible. Test in Task 3.
2. Hand hint while a piece is mid-drag or the tray is scrolling → hand must not appear (any touch restarts the countdown). Test in Task 6.
3. Hand hint when every remaining piece is already loose on the board (tray empty) → hand must pick a loose piece; when the puzzle is complete → no hand. Test in Task 6.
4. System «remove animations» → no flying hand, no confetti, no card press animation, everything still usable. Tests in Tasks 3 and 6.
5. A device that already has progress (update from the current version) → no first-puzzle hand on the next launch. Test in Task 6.

---

### Task 1: Palette, Nunito and theme

**Files:**
- Create: `lib/app/book_palette.dart`
- Create: `assets/fonts/Nunito-SemiBold.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf`, `assets/fonts/OFL.txt`
- Modify: `lib/app/theme.dart`, `pubspec.yaml` (fonts section)
- Test: `test/app/theme_test.dart`

**Interfaces:**
- Produces: `abstract final class BookPalette` with `static const Color paperLight, paper, paperDark, card, text, textMuted, primary, primaryStep, secondaryStep, link, star, outline, shadow;` and `static const List<Color> confetti` (≥ 6 muted colours incl. primary, star, a soft blue, green, pink); `ThemeData buildAppTheme()` (fontFamily 'Nunito', brightness light).

- [ ] **Step 1: Write the failing test** — `theme uses Nunito and the book palette`: `buildAppTheme().textTheme.bodyMedium!.fontFamily == 'Nunito'`, `buildAppTheme().colorScheme.primary == BookPalette.primary`, `buildAppTheme().brightness == Brightness.light`; `contrast(BookPalette.textMuted, BookPalette.card) >= 4.5` and `contrast(BookPalette.text, BookPalette.paperDark) >= 7` (WCAG relative-luminance helper in the test).
- [ ] **Step 2: Run** `flutter test test/app/theme_test.dart` — expected FAIL (no BookPalette).
- [ ] **Step 3: Implement.** Static Nunito TTFs from github.com/googlefonts/nunito (`fonts/ttf/`); if only the variable font is available, bundle it once and map weights with `FontVariation('wght', …)` in the theme. Register weights 600/700/800 in pubspec. Theme: colorScheme from palette (surface = card, onSurface = text), scaffoldBackgroundColor transparent (background drawn by Task 2), text theme weights 700/800, SwitchTheme thumb/track in primary.
- [ ] **Step 4: Run** the test and the whole suite — PASS.

### Task 2: Book widgets

**Files:**
- Create: `lib/app/widgets/paper_background.dart`, `book_button.dart`, `round_icon_button.dart`, `passe_partout.dart`, `book_dialog.dart`
- Test: `test/app/book_widgets_test.dart`

**Interfaces:**
- Consumes: `BookPalette`.
- Produces:
  - `PaperBackground({required Widget child})` — static radial gradient (paperLight at ~20%,15% → paper → paperDark), optional barely-visible grain; wraps a screen body.
  - `enum BookButtonKind { primary, secondary, text }`; `BookButton({required String label, required VoidCallback? onPressed, BookButtonKind kind = BookButtonKind.primary, IconData? icon})` — pill with offset «step» shadow that shrinks while pressed; disabled when onPressed is null.
  - `RoundIconButton({required IconData icon, required String tooltip, required VoidCallback onPressed})` — 48 dp light circle with step, icon colour `BookPalette.text`.
  - `PassePartout({required Widget child, double tiltDegrees = 0, Widget? caption, VoidCallback? onTap})` — card-coloured frame, inner radius 8, outer 12, warm shadow, scale 0.97 while pressed (skipped when `MediaQuery.disableAnimationsOf`), tilt applied with `Transform.rotate` around the centre without changing layout size.
  - `Future<T?> showBookDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true})` and `BookDialog({String? title, required Widget content, List<Widget> actions = const []})`.

- [ ] **Step 1: Write failing tests:** `book button kinds render and respond` (tap primary/secondary/text calls onPressed; null disables); `round icon button is at least 48 dp` (`tester.getSize(...).shortestSide >= 48`, tooltip present); `passe-partout tilt keeps the hit area` (tap at the untilted centre triggers onTap; `getSize` equals untilted size); `passe-partout does not animate with reduced motion` (MediaQuery disableAnimations: true → no `ScaleTransition`/`AnimatedScale` change after press); `book dialog shows title, content and actions`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** the five widgets per the interfaces (no business logic).
- [ ] **Step 4: Run** — PASS.

### Task 3: Catalog screens

**Files:**
- Modify: `lib/features/catalog/catalog_grid.dart` (PictureCard, CatalogHeader, CatalogMessage), `categories_screen.dart`, `category_screen.dart`
- Test: `test/features/catalog/catalog_grid_test.dart` (extend), `test/app/app_test.dart` (adjust finders only)

**Interfaces:**
- Consumes: Task 2 widgets.
- Produces: `PictureCard` keeps its current constructor (image, caption, badge, lockedLabel, onTap) and gains `int index` used for alternating tilt (`index.isEven ? -1.2 : 1.0` degrees).

- [ ] **Step 1: Failing tests:** `card caption ellipsizes and keeps the counter` (360×800 logical portrait-landscape surface 800×360, 3 columns, caption «Морські мешканці» + «★ 0 of 27» → no overflow error, counter text found); `locked card shows a warm lock and still opens the gate` (lock icon colour == BookPalette.primary or card-on-primary; tap → parental gate dialog); `screens draw the paper background` (find.byType(PaperBackground) on categories and category screens); `card has no press animation with reduced motion`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement:** PictureCard → PassePartout with caption row (title 800, star + counter in `BookPalette.star`), locked state blur + lock in a warm circle; header uses RoundIconButton for back/settings and Nunito 800 title; CatalogMessage uses BookButton; both screens wrapped in PaperBackground.
- [ ] **Step 4: Run** the suite — PASS.

### Task 4: Dialogs, paywall, settings, about, puzzle errors + «Подсказки рукой» setting

**Files:**
- Modify: `lib/features/catalog/difficulty_dialog.dart`, `lib/features/purchase/parental_gate.dart`, `lib/features/purchase/paywall_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/features/settings/about_screen.dart`, `lib/features/puzzle/puzzle_screen.dart` (error/loading states only), `lib/features/settings/domain/app_settings.dart`, `lib/features/settings/data/settings_controller.dart`, `lib/l10n/app_{en,uk,ru}.arb`
- Test: `test/features/settings/settings_controller_test.dart`, `test/features/settings/settings_screen_test.dart` (create if absent), existing paywall/about tests (adjust finders)

**Interfaces:**
- Produces: `AppSettings.handHint` (bool, default true) + `copyWith(handHint:)`; `SettingsController.setHandHint(bool)` persisted under key `settings.handHint`; ARB key `handHintSetting` = en «Hand hints», uk «Підказки рукою», ru «Подсказки рукой».

- [ ] **Step 1: Failing tests:** `hand hint setting defaults to on and persists` (fresh prefs → true; setHandHint(false) → prefs bool false, new container reads false); `settings screen toggles hand hints` (switch with l10n text toggles provider); existing paywall/gate/about behaviour tests still pass with new widgets (gate still required before links/buy).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement:** setting + ARB (3 languages, gen-l10n); all listed dialogs via `showBookDialog`/`BookDialog`; paywall buttons Buy = primary, Restore = secondary, links = text; settings rows on PassePartout list with palette switches; about screen on PaperBackground; puzzle error/loading states with BookButton.
- [ ] **Step 4: Run** the suite — PASS.

### Task 5: Puzzle board, tray and win overlay

**Files:**
- Modify: `lib/features/puzzle/game/puzzle_game.dart` (`backgroundColor`), `board_component.dart`, `tray_component.dart`, `lib/features/puzzle/win_overlay.dart`, `lib/features/puzzle/puzzle_screen.dart` (back button → RoundIconButton)
- Test: `test/features/puzzle/win_overlay_test.dart` (extend)

**Interfaces:**
- Consumes: `BookPalette` (Flame paints read the same constants), Task 2 widgets.

- [ ] **Step 1: Failing tests:** `next is primary when there is a next picture` (BookButton with label next has kind primary, play again secondary, back text); `play again is primary without a next picture`; `confetti uses the book palette` (painter colours ⊆ BookPalette.confetti — expose the colour list the painter uses); existing reduced-motion and haptic tests still pass.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement:** game background = paperDark (or transparent over a PaperBackground behind the GameWidget); board = card fill, radius ≈ 12 logical px, warm shadow drawn once; tray = card at ~70% opacity with outline stroke; win card = PassePartout-style, honey star, buttons per Global Constraints.
- [ ] **Step 4: Run** the suite — PASS; build debug APK and look at the board on the tablet emulator (60 FPS target unaffected: shadows/paint objects created once, not per frame).

### Task 6: Hand hint

**Files:**
- Create: `lib/features/puzzle/domain/hand_hint_scheduler.dart` (pure Dart), `lib/features/puzzle/game/hand_hint_component.dart`, `lib/features/puzzle/data/first_puzzle_store.dart`
- Modify: `lib/features/puzzle/game/puzzle_game.dart`, `lib/features/puzzle/puzzle_screen.dart` (pass setting + reduced-motion flag), `lib/features/puzzle/puzzle_controller.dart` (mark first puzzle done on first placed piece)
- Test: `test/features/puzzle/hand_hint_scheduler_test.dart`, `test/features/puzzle/first_puzzle_store_test.dart`

**Interfaces:**
- Produces:
  - `class HandHintScheduler { HandHintScheduler({required bool firstPuzzle, Duration baseDelay = const Duration(seconds: 8)}); void tick(Duration elapsed); void onTouch(); void onPiecePlaced(); void onComplete(); bool get showing; int get showCount; Duration get currentDelay; static const repeatsPerShow = 2; void onShowFinished(); }` — `showing` becomes true when idle time ≥ currentDelay (or immediately if firstPuzzle and nothing placed yet); `onTouch` hides and restarts idle time; `onShowFinished` doubles currentDelay; `onPiecePlaced` resets currentDelay to baseDelay and, if first puzzle, ends first-puzzle mode; `onComplete` stops for good.
  - `HintTarget? pickHintPiece(PuzzleBoard board)` in the scheduler file — first tray piece visible in the tray viewport, else first loose piece, else null; returns piece index + from/to offsets.
  - `FirstPuzzleStore` over SharedPreferences key `hint.firstPuzzleDone`; `bool isDone(bool hasProgress)` returns true if the flag is set or `hasProgress` (existing users).
  - `HandHintComponent` (Flame): draws a cartoon mitten hand with dark outline (Canvas path, no emoji) plus a translucent ghost copy of the piece; flies from→to over ~1.2 s, 2 repeats; reduced motion → static hand at the piece + dashed arrow; `priority` above pieces; never consumes events.

- [ ] **Step 1: Failing scheduler tests (fake clock via tick):** `first puzzle shows immediately`; `not first puzzle shows after 8 s idle`; `touch hides and restarts the 8 s countdown` (tick 7 s, touch, tick 7 s → not showing, tick 1 s → showing); `drag in progress keeps it hidden` (touch at every 2 s for 30 s → never showing); `next show waits double` (show finished → needs 16 s, then 32 s); `placed piece resets the wait to 8 s`; `completed puzzle never shows`; `pickHintPiece prefers a visible tray piece, falls back to a loose piece, null when complete`; store tests: `existing progress counts as first puzzle done`, `flag persists`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** scheduler, store, component; wire in PuzzleGame (`update(dt)` → scheduler.tick; drag start/scroll/tap → onTouch; DropResult.placed → onPiecePlaced; completion → onComplete); disabled entirely when `handHint` is false.
- [ ] **Step 4: Run** the suite — PASS; on the tablet emulator open the first puzzle on a fresh install → hand appears at once; touch → hand disappears.

### Task 7: Category names through the content pipeline

**Files:**
- Modify: `tools/image_pipeline/categories.csv`; regenerated `assets/manifest.json`, `tools/image_pipeline/cdn/manifest.json`; tests that assert old titles (e.g. `test/app/app_test.dart` 'Sea animals' / 'Морські тварини').
- Test: `test/l10n/translations_test.dart` (extend)

- [ ] **Step 1: Failing test:** `category titles match the approved names` — table from Global Constraints asserted against `assets/manifest.json` for all 11 ids × 3 languages.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3:** edit categories.csv; `cd tools/image_pipeline && .venv/bin/python manifest.py --dry-run` (expect 11 category updates, 0 removals, version +1) then without `--dry-run`; update old-title test finders.
- [ ] **Step 4: Run** the suite — PASS; then `.venv/bin/python upload.py --dry-run` (only manifest.json changes) and `.venv/bin/python upload.py`; verify `curl -s https://cdn.animosaic.app/manifest.json` shows the new version and «Собачья семейка».

### Task 8: Device check and store screenshots

**Files:**
- Create: `docs/store/screenshots/phone/*.png`, `docs/store/screenshots/tablet/*.png`

- [ ] **Step 1:** Debug build with CDN + Test Store keys on the phone emulator (Medium_Phone_API_37.0, 20:9) and the tablet emulator: categories, a category with locked cards, puzzle with hand hint, win overlay, paywall, settings. Check: no overflow stripes, captions readable, hand behaves per Task 6.
- [ ] **Step 2:** Capture 4–6 screenshots per form factor (`adb exec-out screencap -p`), no debug banner (release or `debugShowCheckedModeBanner: false` already?) — use a profile/release build for screenshots.
- [ ] **Step 3:** Rebuild the signed release AAB with the command in CLAUDE.md «Release build» and report its size.
