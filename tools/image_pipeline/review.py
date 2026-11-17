"""Review of generated pictures: accept or reject each one against the checklist.

    uv run review.py                  # build review.html for raw/ and open it
    uv run review.py accept farm_pig sea_turtle
    uv run review.py reject spiders_garden
    uv run review.py status

Accepted pictures move to selected/; the first accepted picture of a category
becomes its anchor (anchors/<category>.png). Rejected pictures are deleted from
raw/, so the next generate.py run makes them again.
"""

import argparse
import html
import shutil
import subprocess
import sys

from common import (
    ANCHORS,
    MAX_REJECTS,
    PIPELINE,
    PROJECT,
    RAW,
    SELECTED,
    STYLE_ANCHOR,
    load_animals,
    load_state,
    save_state,
)

CHECKLIST = [
    "Анатомия верная: у пауков 8 ног, у змей нет конечностей, правильное число лап, плавников и пальцев",
    "Нет текста, артефактов, лишних или слитых объектов, лишних глаз на камнях, ракушках и растениях",
    "Контур сплошной и одной толщины, без размытых участков",
    "Стиль совпадает с эталоном и остальной категорией",
    "Животное узнаваемо, не пугает ребёнка, нет острых зубов",
    "Детали есть по всему кадру, в том числе в углах",
]


def _known(ids: list[str]) -> dict:
    animals = {a.id: a for a in load_animals()}
    missing = [i for i in ids if i not in animals]
    if missing:
        raise SystemExit(f"unknown ids: {', '.join(missing)}")
    return animals


def accept(ids: list[str]) -> None:
    animals = _known(ids)
    state = load_state()
    SELECTED.mkdir(exist_ok=True)
    ANCHORS.mkdir(exist_ok=True)
    for id in ids:
        raw = RAW / f"{id}.png"
        if not raw.exists():
            print(f"{id}: nothing in raw/", file=sys.stderr)
            continue
        if (SELECTED / raw.name).exists():
            print(f"{id}: already accepted; delete selected/{raw.name} first to replace it", file=sys.stderr)
            continue
        state["rejects"].pop(id, None)
        shutil.move(raw, SELECTED / raw.name)
        meta = RAW / f"{id}.json"
        if meta.exists():
            shutil.move(meta, SELECTED / meta.name)
        anchor = ANCHORS / f"{animals[id].category}.png"
        note = ""
        if not anchor.exists():
            shutil.copy(SELECTED / raw.name, anchor)
            note = f", now the {animals[id].category} anchor"
        print(f"{id}: accepted{note}")
    save_state(state)


def reject(ids: list[str]) -> None:
    _known(ids)
    state = load_state()
    for id in ids:
        raw = RAW / f"{id}.png"
        if not raw.exists():
            print(f"{id}: nothing in raw/", file=sys.stderr)
            continue
        raw.unlink()
        (RAW / f"{id}.json").unlink(missing_ok=True)
        count = state["rejects"].get(id, 0) + 1
        state["rejects"][id] = count
        print(f"{id}: rejected ({count})")
        if count >= MAX_REJECTS:
            print(f"  {id} rejected {count} times: change its scene or the prompt in animals.csv")
    save_state(state)


def status() -> None:
    rejects = load_state()["rejects"]
    for a in load_animals():
        if (SELECTED / f"{a.id}.png").exists():
            where = "accepted"
        elif (RAW / f"{a.id}.png").exists():
            where = "awaiting review"
        else:
            where = "to generate"
        extra = f", rejected {rejects[a.id]}x" if a.id in rejects else ""
        print(f"{a.id:24} {a.category:10} {where}{extra}")


def build_html() -> None:
    animals = [a for a in load_animals() if (RAW / f"{a.id}.png").exists()]
    if not animals:
        print("raw/ is empty: nothing to review")
        return
    checklist = "".join(f"<li>{html.escape(item)}</li>" for item in CHECKLIST)
    cards = []
    for a in animals:
        anchor = ANCHORS / f"{a.category}.png"
        ref_src = (
            f"anchors/{anchor.name}"
            if anchor.exists()
            else "../../" + STYLE_ANCHOR.relative_to(PROJECT).as_posix()
        )
        cards.append(
            f"""<section>
  <h2>{html.escape(a.id)} <small>{html.escape(a.category)} · {html.escape(a.title['ru'])}</small></h2>
  <div class="pair">
    <figure><img src="raw/{a.id}.png" loading="lazy"><figcaption>Новая</figcaption></figure>
    <figure><img src="{html.escape(ref_src)}" loading="lazy"><figcaption>Эталон</figcaption></figure>
  </div>
  <p class="scene">{html.escape(a.animal)} — {html.escape(a.scene)}</p>
</section>"""
        )
    ids = " ".join(a.id for a in animals)
    page = f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><title>Проверка картинок</title>
<style>
body {{ font: 15px/1.4 system-ui, sans-serif; margin: 24px; background: #f4f4f6; color: #222; }}
section {{ background: #fff; border-radius: 10px; padding: 16px; margin: 0 0 20px; }}
h2 small {{ font-weight: normal; color: #777; }}
.pair {{ display: grid; grid-template-columns: 3fr 1fr; gap: 12px; align-items: start; }}
img {{ width: 100%; border-radius: 6px; }}
figure {{ margin: 0; }} figcaption {{ color: #777; font-size: 13px; }}
code {{ background: #eee; padding: 2px 6px; border-radius: 4px; }}
</style></head><body>
<h1>Проверка: {len(animals)} шт.</h1>
<p>Чек-лист:</p><ol>{checklist}</ol>
<p>Принять: <code>uv run review.py accept {ids}</code><br>
Забраковать: <code>uv run review.py reject &lt;id&gt; …</code></p>
{''.join(cards)}
</body></html>
"""
    out = PIPELINE / "review.html"
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out}")
    if sys.platform == "darwin":
        subprocess.run(["open", str(out)], check=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command")
    for name in ("accept", "reject"):
        p = sub.add_parser(name)
        p.add_argument("ids", nargs="+")
    sub.add_parser("status")
    args = parser.parse_args()
    if args.command == "accept":
        accept(args.ids)
    elif args.command == "reject":
        reject(args.ids)
    elif args.command == "status":
        status()
    else:
        build_html()


if __name__ == "__main__":
    main()
