# Референсы иллюстраций для пазлов

Эталон стиля для генерации финальных картинок (этап 3) — `style_anchor.png`, правила стиля — `STYLE.md`.

Шесть тестовых картинок ниже нарисованы в прежнем, плоском стиле без контуров. Это временный контент для разработки (этапы 1–2 плана), как эталон стиля они больше не используются.

| Файл | Категория (id) | Животное |
| --- | --- | --- |
| sea_turtle | sea | Морская черепаха |
| farm_pig | farm | Поросёнок |
| savanna_giraffe | savanna | Жираф |
| canines_fox | canines | Лиса |
| felines_cat | felines | Кошка |
| snake_jungle | snakes | Змея |

- `style_anchor.png` — эталон стиля (акула-молот), 1200 × 896, оригинал генерации без обработки.
- `png/` — растр 2048 × 1536 (4:3), сейчас лежит в `assets/images/free/` как картинки пазлов.
- `svg/` — исходники временных картинок.
- `preview.png` — сводный лист временных картинок.

Финальные картинки заменят временные в `assets/images/free/` по тем же id.

Рендер PNG из SVG: `pip install cairosvg`, затем
`python -c "import cairosvg; cairosvg.svg2png(url='svg/x.svg', write_to='png/x.png', output_width=2048, output_height=1536)"`.
