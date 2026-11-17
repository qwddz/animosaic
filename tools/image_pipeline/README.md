# Пайплайн картинок (этап 3)

Генерация картинок пазлов через Nano Banana 2 Lite (`gemini-3.1-flash-lite-image`) по эталону стиля `docs/puzzle_refs/style_anchor.png`. Правила стиля — `docs/puzzle_refs/STYLE.md`, процесс — `docs/PLAN.md`, раздел «Пайплайн генерации картинок».

## Подготовка

1. Ключи в `.env` в корне проекта (или переменные окружения): `GEMINI_API_KEY` (генерация); `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` (только для `upload.py`).
2. Зависимости: `uv sync` в этой папке.

## Цикл

```bash
cd tools/image_pipeline
uv run generate.py                 # 1 вариант на картинку в raw/ (--id, --category, --dry-run)
uv run generate.py --budget 9 --workers 4   # лимит расчётных трат за запуск, параллельные запросы
uv run review.py                   # review.html: новая картинка рядом с эталоном + чек-лист
uv run review.py accept <id> ...   # в selected/; первая принятая в категории → anchors/<category>.png
uv run review.py reject <id> ...   # удалить из raw/; следующий generate.py сделает заново
uv run review.py status            # что принято, что ждёт проверки, сколько браков
uv run process.py                  # selected/ → processed/: 4:3, 2048×1536 WebP, превью, sha256
uv run manifest.py --dry-run       # затем без --dry-run: полный манифест, превью, cdn/
uv run upload.py --dry-run         # затем без --dry-run: cdn/ → Cloudflare R2
```

Бесплатные картинки (order ≤ 5) генерируются первыми. Расчётные траты по токенам пишутся в `raw/<id>.json` и суммируются в `state.json` — сверяйте с биллингом Google. Повторный `generate.py` пропускает принятые и ожидающие проверки картинки, поэтому генерирует только брак. После третьего брака подряд `review.py` просит поменять сцену или промпт в `animals.csv`.

## Файлы

- `animals.csv` — картинки: id, категория, названия uk/en/ru, `animal`/`habitat`/`scene` (английский, идут в промпт), `free`, `order`.
- `categories.csv` — 11 категорий с названиями и порядком.
- `prompt.txt` — шаблон промпта.
- `raw/`, `selected/`, `anchors/`, `processed/`, `state.json`, `review.html` — рабочие файлы, создаются скриптами.

## manifest.py и CDN

`manifest.py` собирает полный манифест (схема 2) по `animals.csv`/`categories.csv` для всех картинок с `processed/<id>.webp`, одним и тем же JSON в `assets/manifest.json` и `cdn/manifest.json`. У каждой записи есть и встроенные пути, и поля CDN: приложение берёт встроенный файл, если он есть в его сборке, иначе качает с CDN. Так старые сборки получают новые картинки и превью обновлением одного CDN.

- бесплатные: `asset` = `images/free/<id>.webp`, файл копируется в `assets/images/free/`;
- все: `url` = `pictures/<id>-<sha8>.webp`, `sha256`, `bytes`; файл копируется в `cdn/pictures/`;
- все: `thumb` = `thumbs/<id>.webp` (превью из `processed/preview/` → `assets/thumbs/`, встроено) и `thumbUrl` = `thumbs/<id>-<sha8 превью>.webp` (→ `cdn/thumbs/`);
- `version` +1, если содержимое категорий изменилось; `minAppVersion` сохраняется; категории не из `categories.csv` остаются как были.

Картинка из текущего `assets/manifest.json` не пропадает молча. Если она выпадет из нового манифеста (нет `processed/` или превью, `selected/` новее `processed/`, строка удалена из `animals.csv`), скрипт ничего не пишет и печатает эти id с причиной. Удалить намеренно: `--remove <id>` на каждый id (повторяемый; так же можно убрать и обработанную картинку).

`--dry-run` печатает изменения построчно: `add/update/remove entry <id>` (для update — изменившиеся поля), `add/update file <путь>`, `remove file <путь>`, и итог. Без `--dry-run` печатает то же и выполняет. Файлы копируются до записи манифеста (temp + `os.replace`); устаревшие (`assets/` из старого манифеста, `cdn/pictures/` и `cdn/thumbs/` без ссылок) удаляются после. `cdn/` — рабочая папка, в `.gitignore`.

`upload.py` грузит `cdn/` в R2 по S3 API:

1. проверяет, что каждый `url`/`thumbUrl` из `cdn/manifest.json` есть в `cdn/` или уже в бакете (HEAD); иначе ничего не грузит;
2. читает `manifest.json`, лежащий сейчас в бакете;
3. грузит `pictures/` и `thumbs/` (объекты с тем же размером пропускаются; `image/webp`, `Cache-Control: public, max-age=31536000, immutable`);
4. последним — `manifest.json` (`max-age=300`).

`--dry-run` показывает список без изменений (без ключей — без сети). `--delete-stale` (по умолчанию выключено) удаляет из `pictures/` и `thumbs/` бакета только объекты, на которые не ссылается ни старый манифест из бакета, ни новый: приложения со старым манифестом продолжают качать свои файлы. С `--dry-run` печатает, что было бы удалено.

`R2_ACCOUNT_ID` — id аккаунта (адрес `https://<id>.r2.cloudflarestorage.com`) или полный адрес S3 API из настроек бакета. Для бакетов с юрисдикцией EU вставляйте полный адрес S3 API (`https://<id>.eu.r2.cloudflarestorage.com/...`; путь после домена отбрасывается).

`CDN_BASE_URL` приложения (`--dart-define`) — публичный адрес бакета, сейчас `https://cdn.animosaic.app` (без `/` в конце); манифест лежит в `<base>/manifest.json`.

Приложение отвергает манифест с CDN, в котором нет картинок или пропало больше 10% id текущего манифеста. Крупное удаление контента — только через обновление приложения или несколькими шагами.
