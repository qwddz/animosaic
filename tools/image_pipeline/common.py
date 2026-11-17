"""Shared paths, CSV loading and state for the image pipeline scripts."""

import csv
import json
import os
from dataclasses import dataclass
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent
PROJECT = PIPELINE.parents[1]

STYLE_ANCHOR = PROJECT / "docs" / "puzzle_refs" / "style_anchor.png"
MANIFEST = PROJECT / "assets" / "manifest.json"
FREE_ASSETS = PROJECT / "assets" / "images" / "free"
THUMB_ASSETS = PROJECT / "assets" / "thumbs"
CDN = PIPELINE / "cdn"
CDN_MANIFEST = CDN / "manifest.json"

RAW = PIPELINE / "raw"
SELECTED = PIPELINE / "selected"
ANCHORS = PIPELINE / "anchors"
PROCESSED = PIPELINE / "processed"
STATE = PIPELINE / "state.json"

# How many times a picture may be rejected before its scene or prompt has to
# change in animals.csv (docs/PLAN.md, pipeline step 3).
MAX_REJECTS = 3


@dataclass(frozen=True)
class Animal:
    id: str
    category: str
    title: dict[str, str]
    animal: str
    habitat: str
    scene: str
    free: bool
    order: int


@dataclass(frozen=True)
class Category:
    id: str
    title: dict[str, str]
    order: int


def _title(row: dict[str, str]) -> dict[str, str]:
    return {code: row[f"title_{code}"] for code in ("uk", "en", "ru")}


def load_categories() -> dict[str, Category]:
    with open(PIPELINE / "categories.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return {
        r["id"]: Category(id=r["id"], title=_title(r), order=int(r["order"]))
        for r in rows
    }


def load_animals() -> list[Animal]:
    categories = load_categories()
    with open(PIPELINE / "animals.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    animals = []
    seen = set()
    for r in rows:
        if r["id"] in seen:
            raise SystemExit(f"animals.csv: duplicate id {r['id']}")
        if r["category"] not in categories:
            raise SystemExit(f"animals.csv: unknown category {r['category']}")
        if r["free"] not in ("true", "false"):
            raise SystemExit(f"animals.csv: free must be true or false ({r['id']})")
        seen.add(r["id"])
        animals.append(
            Animal(
                id=r["id"],
                category=r["category"],
                title=_title(r),
                animal=r["animal"],
                habitat=r["habitat"],
                scene=r["scene"],
                free=r["free"] == "true",
                order=int(r["order"]),
            )
        )
    return animals


def select(animals: list[Animal], ids: list[str], category: str | None) -> list[Animal]:
    """Filters by --id and --category; unknown ids are an error."""
    if category is not None and category not in load_categories():
        raise SystemExit(f"unknown category: {category}")
    known = {a.id for a in animals}
    missing = [i for i in ids if i not in known]
    if missing:
        raise SystemExit(f"unknown ids: {', '.join(missing)}")
    return [
        a
        for a in animals
        if (not ids or a.id in ids) and (category is None or a.category == category)
    ]


def load_state() -> dict:
    if not STATE.exists():
        return {"rejects": {}}
    return json.loads(STATE.read_text(encoding="utf-8"))


def save_state(state: dict) -> None:
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_env() -> None:
    """Reads KEY=VALUE lines from the project .env without overriding the environment."""
    env = PROJECT / ".env"
    if not env.exists():
        return
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))
