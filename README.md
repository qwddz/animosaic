# Animosaic: пазлы с животными

Детская игра-пазл на Flutter + Flame. Ребёнок выбирает картинку с животным, количество кусочков и перетаскивает кусочки с ленты на поле, пока картинка не сложится. Android, только альбомная ориентация, телефоны и планшеты.

- Пакет: `app.animosaic.puzzles` (не менять: к нему привязаны Play Console и покупка `full_version`).
- Сайт, политика конфиденциальности и условия: https://animosaic.app (исходники в `site/`).
- План продукта, этапы и критерии готовности: [`docs/PLAN.md`](docs/PLAN.md).
- Правила работы с кодом для Claude Code: [`CLAUDE.md`](CLAUDE.md).

## Содержание

- [Что внутри](#что-внутри)
- [Стек](#стек)
- [Быстрый старт](#быстрый-старт)
- [Переменные окружения и `.env`](#переменные-окружения-и-env)
- [Команды](#команды)
- [Архитектура](#архитектура)
- [Контент: картинки, манифест, CDN](#контент-картинки-манифест-cdn)
- [Полная версия и покупки](#полная-версия-и-покупки)
- [Код доступа для проверяющих Google Play](#код-доступа-для-проверяющих-google-play)
- [Локализация](#локализация)
- [Тесты](#тесты)
- [Релизная сборка](#релизная-сборка)
- [Публикация в Google Play](#публикация-в-google-play)
- [Структура репозитория](#структура-репозитория)

## Что внутри

- 297 картинок в 11 категориях (морские животные, ферма, домашние, джунгли, саванна, пустыня, пауки, акулы, змеи, кошачьи, псовые).
- 55 картинок бесплатные и встроены в приложение; остальные 242 открываются разовой покупкой «Полная версия» и скачиваются с CDN при первом открытии.
- 4 уровня сложности: 6, 12, 24 и 48 кусочков.
- Подсказки: бледная картинка на поле и рука, показывающая жест; звуки и музыка.
- Прогресс (лучшая сложность по каждой картинке) и незаконченный пазл сохраняются на устройстве.
- Языки: английский, украинский, русский.
- Без рекламы, аналитики и аккаунтов. Покупка и внешние ссылки закрыты родительской проверкой (вопрос на умножение).

## Стек

| Что | Чем |
|---|---|
| UI, меню, каталог, paywall, настройки | Flutter (Material, свои виджеты в `lib/app/widgets/`) |
| Экран пазла | Flame (`GameWidget`), мост с состоянием через `flame_riverpod` |
| Состояние | Riverpod 3 |
| Навигация | go_router |
| Покупки | RevenueCat (`purchases_flutter`) поверх Google Play Billing |
| Сеть (манифест, картинки) | dio, Cloudflare R2 за `cdn.animosaic.app` |
| Хранение | JSON-файлы (прогресс, незаконченный пазл), SharedPreferences (настройки) |
| Звук | flame_audio |
| Пайплайн картинок | Python + uv, Gemini (Nano Banana 2 Lite) |

Версии: Flutter 3.47 (stable), Dart SDK `^3.13.5`. Точные версии пакетов — в `pubspec.yaml` / `pubspec.lock`.

## Быстрый старт

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter emulators --launch Medium_Phone_API_37.0   # телефон 20:9
flutter run -d <device-id>                         # id из `flutter devices`
```

Без дополнительных флагов debug-сборка работает так:

- доступны только встроенные бесплатные картинки (платные без `CDN_BASE_URL` скачать неоткуда);
- вместо Google Play работает «тестовый магазин» (`FakePurchaseService`): покупка проходит мгновенно и ничего не стоит, SDK RevenueCat не инициализируется.

С платными картинками и настоящими покупками:

```bash
flutter run -d <device-id> --dart-define=CDN_BASE_URL=https://cdn.animosaic.app
flutter run -d <device-id> --dart-define=CDN_BASE_URL=https://cdn.animosaic.app \
  --dart-define=REVENUECAT_API_KEY=$(grep '^REVENUECAT_GOOGLE_API_KEY=' .env | cut -d= -f2-)
```

## Переменные окружения и `.env`

Секреты живут только в `.env` в корне проекта (в репозиторий и сборку не попадают целиком) или в переменных окружения. В коде и ассетах ключей нет.

| Переменная | Для чего | Куда передаётся |
|---|---|---|
| `REVENUECAT_GOOGLE_API_KEY` | публичный Android-ключ RevenueCat (`goog_…`), настоящие покупки | `--dart-define=REVENUECAT_API_KEY=…` в релизе |
| `REVENUECAT_API_KEY` | ключ Test Store RevenueCat (`test_…`) для debug | `--dart-define=REVENUECAT_API_KEY=…` |
| `REVENUECAT_SECRET_KEY` | секретный ключ API v2 (`sk_…`), только для настройки проекта RevenueCat | **никогда** не передавать в сборку |
| `REVIEW_CODE` | код доступа для проверяющих Google Play | в сборку идёт только его sha256: `REVIEW_CODE_SHA256` |
| `GEMINI_API_KEY` | генерация картинок | `tools/image_pipeline/generate.py` |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | загрузка контента в Cloudflare R2 | `tools/image_pipeline/upload.py` |

Флаги сборки (`--dart-define`):

| Флаг | Без него |
|---|---|
| `CDN_BASE_URL` | debug: только бесплатные картинки; **release не запустится** |
| `REVENUECAT_API_KEY` | debug: тестовый магазин; **release не запустится** (нужен `goog_…`) |
| `REVIEW_CODE_SHA256` | кнопки «I have an access code» на paywall нет |

## Команды

```bash
flutter pub get                                   # зависимости
flutter gen-l10n                                  # пересобрать lib/l10n/app_localizations*.dart из ARB
flutter analyze                                   # должно быть "No issues found"
dart format lib test                              # форматирование
flutter test                                      # все тесты
flutter test test/app/locale_test.dart            # один файл
flutter test --plain-name "falls back to English" # один тест по имени
flutter emulators --launch Medium_Phone_API_37.0  # эмулятор телефона (20:9)
flutter emulators --launch Tablet_API_37          # эмулятор планшета (2560×1600, 16:10)
flutter run --profile -d <device-id>              # замер FPS / производительности
```

Перед тем как считать задачу готовой: `flutter gen-l10n` (если менялись ARB) → `dart format lib test` → `flutter analyze` → `flutter test`. Изменения UI и игры дополнительно проверяются на эмуляторах телефона и планшета.

## Архитектура

```
lib/
├── main.dart            альбомная ориентация, SharedPreferences, ProviderScope
├── app/                 PuzzlesApp (MaterialApp.router), routerProvider, тема, resolveAppLocale, общие виджеты
├── core/                общие утилиты (json_file_store.dart и др.)
├── l10n/                ARB-файлы и сгенерированные AppLocalizations
└── features/
    ├── catalog/         категории, сетка картинок, выбор сложности, ContentManifest
    ├── content/         манифест с CDN, PictureStore (скачивание и проверка sha256)
    ├── puzzle/          экран пазла: domain/ (чистый Dart), game/ (Flame), data/, PuzzleController
    ├── progress/        progressProvider: лучшая сложность по каждой картинке
    ├── purchase/        полная версия: PurchaseService, paywall, родительская проверка, код для ревью
    ├── settings/        звук, музыка, подсказки, язык; экран «О приложении»
    └── audio/           звуки и музыка
```

Принципы:

- **Состояние — в провайдерах Riverpod.** Виджеты только рисуют и передают события, бизнес-логики в них нет.
- **Flame — только на экране пазла.** Меню, каталог, paywall и настройки — обычные Flutter-виджеты.
- **Нарезка пазла — чистый Dart без Flame** (`features/puzzle/domain/`): `PuzzleCut` и `PieceGeometry` режут картинку по сетке и seed, `PuzzleLayout` и `TrayGeometry` раскладывают поле и ленту, `PuzzleSession` — сохраняемое состояние, `PuzzleBoard` — правила взаимодействия (прокрутка ленты или захват кусочка, примагничивание, свободные кусочки). Поэтому всё это покрыто юнит-тестами.
- **Flame-компоненты** (`features/puzzle/game/`) только следуют за `board.positions` и `board.scales` и передают перетаскивания. Кусочки заранее отрисованы в изображения.
- **`PuzzleController`** (Riverpod family по картинке и сложности) отвечает за загрузку, сохранение после каждого отпускания кусочка, завершение, перезапуск и запись прогресса.

Маршруты:

| Путь | Экран |
|---|---|
| `/` | категории |
| `/category/:id` | картинки категории |
| `/puzzle/:id?difficulty=` | игра |
| `/paywall?from=<puzzleId>&difficulty=` | полная версия; после покупки открывает `from`, иначе возвращает назад |
| `/settings` | настройки |

## Контент: картинки, манифест, CDN

- `assets/manifest.json` (`ContentManifest`) — список категорий и картинок. В рантайме его заменяет более новый валидный `manifest.json` с CDN.
- `assets/images/free/` — 55 бесплатных картинок (WebP), `assets/thumbs/` — превью всех 297.
- Платные картинки скачиваются с CDN при первом открытии, проверяются по sha256 и кешируются в папке поддержки приложения (`PictureStore`). У каждой записи манифеста есть и поля CDN, так что сборка без встроенного файла сама возьмёт его с CDN.
- CDN — бакет Cloudflare R2 `puzzles` (EU) на `cdn.animosaic.app`. URL в манифесте относительные, переезд CDN меняет только `CDN_BASE_URL`.

Картинки делает пайплайн `tools/image_pipeline/` (Python, `uv`): generate → review → process → manifest → upload. Подробно — в [`tools/image_pipeline/README.md`](tools/image_pipeline/README.md). Стиль задают эталон `docs/puzzle_refs/style_anchor.png` и `docs/puzzle_refs/STYLE.md`.

- Генерация платная: всегда передавайте `--budget`.
- Записи картинок в `assets/manifest.json` руками не правятся, их пишет `manifest.py`.

Звуки синтезирует `tools/audio/synth.py` (см. [`tools/audio/README.md`](tools/audio/README.md)).

## Полная версия и покупки

- Одна разовая покупка без подписки: продукт Google Play `full_version` → entitlement RevenueCat `full` (единственный, который проверяет приложение), offering `default`, пакет `$rc_lifetime`. Проект RevenueCat — `animosaic.app`.
- `PurchaseService` — интерфейс с реализациями RevenueCat и фейковой (`FakePurchaseService`). `fullAccessProvider` следит за покупками, восстановлением и возвратами.
- Единое правило доступа — `canPlay` / `canPlayProvider(entry)`: `entry.free || fullAccess`. Через него идут:
  - карточки каталога (размытое превью и замок → родительская проверка → paywall);
  - редирект `/puzzle/:id` на paywall для закрытой картинки;
  - `PuzzleController` (бросает `PuzzleLockedException`);
  - кнопка «Дальше» на экране победы (`nextPlayableProvider` пропускает закрытые картинки, ребёнок из игры на paywall не попадает).

## Код доступа для проверяющих Google Play

Проверяющие Google не покупают контент, поэтому на paywall есть кнопка «I have an access code» (`lib/features/purchase/data/review_access.dart`, `review_code_dialog.dart`).

- Код — `REVIEW_CODE` в `.env`. В сборку попадает только sha256 нормализованного кода (заглавные буквы и цифры, без дефисов и пробелов) через `--dart-define=REVIEW_CODE_SHA256`.
- Верный код открывает полную версию на этом устройстве без покупки и аккаунта. Без `REVIEW_CODE_SHA256` кнопки нет.
- Устройство запоминает хэш введённого кода. Сборка с новым кодом закрывает доступ всем, кто вводил старый.
- Код и инструкция для проверяющих вписаны в Play Console → «Содержание приложения» → «Учётные данные». При смене кода обновите декларацию вместе с новой сборкой. Посторонним тестерам код не давайте.

Сменить код:

```bash
python3 -c "import secrets;a='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';s=''.join(secrets.choice(a) for _ in range(16));print('-'.join(s[i:i+4] for i in range(0,16,4)))"
# заменить REVIEW_CODE=… в .env, собрать релиз, обновить «Учётные данные» в Play Console
```

## Локализация

- В коде нет строк для пользователя: все тексты в `lib/l10n/app_en.arb` (шаблон), `app_uk.arb` и `app_ru.arb`, затем `flutter gen-l10n`. Сгенерированные `app_localizations*.dart` руками не правятся.
- Язык: из настроек, иначе первый поддерживаемый язык устройства, иначе английский (`resolveAppLocale`).
- Названия категорий и животных приходят из манифеста по id.
- Название приложения на иконке — не в ARB, а в `android/app/src/main/res/values{,-uk,-ru}/strings.xml` (`app_name`).

## Тесты

```bash
flutter test
```

`test/` повторяет структуру `lib/`. Обязательно покрыты нарезка пазла и хранение прогресса. `test/features/puzzle/puzzle_board_test.dart` собирает пазл каждой сложности на нескольких размерах экрана через `PuzzleBoard`. Покупки, paywall, родительская проверка и код для ревью проверяются в `test/features/purchase/`.

## Релизная сборка

Ключ загрузки лежит вне проекта. Создаётся один раз:

```bash
mkdir -p ~/keys/puzzles
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v \
  -keystore ~/keys/puzzles/upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`~/keys/puzzles/key.properties`:

```properties
storeFile=/Users/<you>/keys/puzzles/upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Сборка AAB:

```bash
PUZZLES_KEY_PROPERTIES=~/keys/puzzles/key.properties flutter build appbundle --release \
  --build-number=$(date -u +%y%m%d%H) \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=CDN_BASE_URL=https://cdn.animosaic.app \
  --dart-define=REVENUECAT_API_KEY=$(grep '^REVENUECAT_GOOGLE_API_KEY=' .env | cut -d= -f2-) \
  --dart-define=REVIEW_CODE_SHA256=$(grep '^REVIEW_CODE=' .env | cut -d= -f2- | tr -cd 'A-Z0-9' | shasum -a 256 | cut -c1-64)
```

Результат: `build/app/outputs/bundle/release/app-release.aab` (~83 МБ со всеми ABI; Play отдаёт один ABI, около 38 МБ на arm64).

- **versionCode** должен расти с каждой загрузкой в Play. `--build-number` из даты и часа UTC (`26111710`) растёт сам; две загрузки в один час требуют ручного номера. Один и тот же AAB повторно в Play не загружается — в другой трек его добавляют «из библиотеки». `versionName` берётся из `version:` в `pubspec.yaml`.
- **Символы.** `--obfuscate` переименовывает Dart-символы. Для каждой загруженной сборки сохраняйте `build/symbols` (например, в `~/keys/puzzles/symbols/<build-number>/`): `flutter clean` их удаляет. Расшифровка: `flutter symbolize -i <trace.txt> -d build/symbols/app.android-arm64.symbols`.
- **R8** включён (`isMinifyEnabled`, `isShrinkResources`). Java-маппинг и нативные символы упакованы в AAB, Play Console расшифровывает Java/native-крэши сам. Если release падает с `ClassNotFoundException` / `NoSuchMethodError`, а debug нет — добавьте `-keep` в `android/app/proguard-rules.pro`.
- **«failed to strip debug symbols»** в конце сборки: не хватает компонента Android SDK `cmdline-tools` (Android Studio → SDK Manager → SDK Tools). AAB при этом уже записан и нативные библиотеки урезаны.
- Без `PUZZLES_KEY_PROPERTIES` релиз подписывается debug-ключом, и Play его отклонит.
- Проверить релиз на эмуляторе: `flutter build apk --release` с теми же флагами и `adb install`. Ключ отличается от debug, поэтому сначала удалите debug-версию (прогресс сотрётся).

Android: активити `sensorLandscape`, приложение объявляет `android:appCategory="game"` (держит альбомную ориентацию на больших экранах Android 16+). Сохраняйте оба при правке `AndroidManifest.xml`.

## Публикация в Google Play

Всё для Play Console лежит в [`docs/store/`](docs/store/):

| Файл | Что |
|---|---|
| [`listing.md`](docs/store/listing.md) | название, краткое и полное описание на en / uk / ru с подсчётом символов |
| [`play_console.md`](docs/store/play_console.md) | ответы для «Содержания приложения»: учётные данные, реклама, IARC, целевая аудитория, безопасность данных |
| `icon_512.png` | значок 512×512 |
| `feature_graphic_1024x500.png` | баннер 1024×500 |
| `screenshots/phone/`, `screenshots/tablet/` | скриншоты 2400×1200 и 2560×1600 (английские; `ru/` — русские) |

Порядок выпуска:

1. Собрать AAB (см. выше), загрузить в трек, сохранить символы.
2. Проверить декларации: «Учётные данные» с актуальным кодом, рекламный ID — «Нет» (в манифесте нет `AD_ID`), безопасность данных — как в `play_console.md`.
3. Личный аккаунт разработчика: перед рабочей версией нужен закрытый тест — не меньше 12 тестеров, подписанных 14 дней подряд. Тестеры добавляются Google-группами в треке «Закрытое тестирование». Выпуск в треке нужно отправить на проверку («Обзор публикации»), иначе ссылки для тестеров не работают.
4. После теста — заявка на доступ к рабочей версии. Записывайте отзывы тестеров и что по ним исправлено: об этом спросят в заявке.

При добавлении любой новой зависимости проверяйте слитый релизный манифест (`build/app/intermediates/merged_manifest/release/…/AndroidManifest.xml`) на новые разрешения, особенно `AD_ID`, и пересматривайте раздел «Безопасность данных».

## Структура репозитория

```
android/            Android-проект (Gradle Kotlin DSL, R8, подпись через PUZZLES_KEY_PROPERTIES)
assets/             manifest.json, бесплатные картинки, превью, звуки, иконка, шрифты
docs/PLAN.md        план продукта и этапы
docs/puzzle_refs/   эталон стиля картинок
docs/store/         материалы для Google Play
lib/                код приложения
site/               сайт animosaic.app: главная, политика, условия
test/               тесты (повторяют lib/)
tools/image_pipeline/  генерация и публикация картинок
tools/audio/        синтез звуков
tools/store/        генерация вариантов иконки
```

Git в проекте пока не используется.
