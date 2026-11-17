"""Builds the full manifest (schema 2) and the files it points to.

- assets/manifest.json and cdn/manifest.json: the same JSON, all pictures;
- free pictures -> assets/images/free/<id>.webp ("asset");
- every picture -> cdn/pictures/<id>-<sha8>.webp ("url", "sha256", "bytes");
- every preview -> assets/thumbs/<id>.webp ("thumb") and
  cdn/thumbs/<id>-<sha8>.webp ("thumbUrl").

The app prefers bundled files and falls back to the CDN fields, so builds
that lack a picture or preview still show it after a CDN-only update.

A picture in the current assets/manifest.json never disappears silently: if
it would be missing from the new one, nothing is written unless --remove names
it. `version` grows by 1 when the categories content changes.

    uv run manifest.py --dry-run
    uv run manifest.py
    uv run manifest.py --remove <id> --remove <id>
"""

import argparse
import hashlib
import json
import os
import shutil

from common import (
    CDN,
    CDN_MANIFEST,
    FREE_ASSETS,
    MANIFEST,
    PROCESSED,
    PROJECT,
    SELECTED,
    THUMB_ASSETS,
    load_animals,
    load_categories,
)

PICTURES = CDN / "pictures"
THUMBS = CDN / "thumbs"


def write_json(path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def content_name(folder: str, id_: str, data: bytes) -> tuple[str, str]:
    sha = hashlib.sha256(data).hexdigest()
    return f"{folder}/{id_}-{sha[:8]}.webp", sha


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="show the changes without writing")
    parser.add_argument(
        "--remove", action="append", default=[], metavar="ID",
        help="allow this picture to leave the manifest (repeatable); it is left out even if processed",
    )
    args = parser.parse_args()
    remove = set(args.remove)

    old = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    old_categories = old.get("categories", [])
    old_entries = {p["id"]: p for c in old_categories for p in c["puzzles"]}
    categories = load_categories()
    animals = sorted(load_animals(), key=lambda a: a.order)
    unknown = sorted(remove - old_entries.keys() - {a.id for a in animals})
    if unknown:
        raise SystemExit(f"--remove: unknown ids: {', '.join(unknown)}")

    puzzles: dict[str, list[dict]] = {c: [] for c in categories}
    copies = []  # (source, destination)
    skipped: dict[str, str] = {}  # id -> reason

    for a in animals:
        if a.id in remove:
            skipped[a.id] = "--remove"
            continue
        image = PROCESSED / f"{a.id}.webp"
        if not image.exists():
            skipped[a.id] = f"no processed/{a.id}.webp"
            continue
        source = SELECTED / f"{a.id}.png"
        if source.exists() and source.stat().st_mtime > image.stat().st_mtime:
            skipped[a.id] = "selected/ is newer than processed/, run process.py"
            continue
        preview = PROCESSED / "preview" / f"{a.id}.webp"
        if not preview.exists():
            skipped[a.id] = f"no processed/preview/{a.id}.webp, run process.py"
            continue
        entry = {"id": a.id, "title": a.title, "free": a.free}
        if a.free:
            entry["asset"] = f"images/free/{a.id}.webp"
            copies.append((image, FREE_ASSETS / f"{a.id}.webp"))
        data = image.read_bytes()
        url, sha = content_name("pictures", a.id, data)
        entry.update({"url": url, "sha256": sha, "bytes": len(data)})
        copies.append((image, CDN / url))
        thumb_url, _ = content_name("thumbs", a.id, preview.read_bytes())
        entry["thumb"] = f"thumbs/{a.id}.webp"
        entry["thumbUrl"] = thumb_url
        copies.append((preview, THUMB_ASSETS / f"{a.id}.webp"))
        copies.append((preview, CDN / thumb_url))
        puzzles[a.category].append(entry)

    new_categories = [
        {"id": c.id, "title": c.title, "puzzles": puzzles[c.id]}
        for c in sorted(categories.values(), key=lambda c: c.order)
        if puzzles[c.id]
    ]
    # Categories absent from categories.csv stay as they were.
    new_categories += [c for c in old_categories if c["id"] not in categories]

    entries = [p for c in new_categories for p in c["puzzles"]]
    new_entries = {p["id"]: p for p in entries}

    # Pictures that would leave the manifest must be named by --remove.
    removed = [i for i in old_entries if i not in new_entries]
    unconfirmed = [i for i in removed if i not in remove]
    if unconfirmed:
        print(f"error: {len(unconfirmed)} picture(s) in {MANIFEST.relative_to(PROJECT)} would be removed:")
        for i in unconfirmed:
            print(f"  {i}: {skipped.get(i, 'not in animals.csv')}")
        raise SystemExit("nothing written; fix the cause or confirm with --remove <id> for each")
    for i, reason in skipped.items():
        if i not in old_entries:
            print(f"warning: {i}: {reason}; not added")

    changed = new_categories != old_categories
    version = old.get("version", 0) + (1 if changed else 0) if old else 1
    manifest = {
        "version": version,
        "minAppVersion": old.get("minAppVersion", "1.0.0"),
        "categories": new_categories,
    }

    # Entry changes.
    added = [i for i in new_entries if i not in old_entries]
    updated = [i for i in new_entries if i in old_entries and new_entries[i] != old_entries[i]]
    for i in added:
        print(f"add entry {i}")
    for i in updated:
        keys = sorted(k for k in new_entries[i].keys() | old_entries[i].keys()
                      if new_entries[i].get(k) != old_entries[i].get(k))
        print(f"update entry {i}: {', '.join(keys)}")
    for i in removed:
        print(f"remove entry {i} (--remove)")

    # File changes.
    to_copy = []
    for src, dst in copies:
        if not dst.exists():
            to_copy.append((src, dst, "add"))
        elif dst.read_bytes() != src.read_bytes():
            to_copy.append((src, dst, "update"))
    for src, dst, kind in to_copy:
        print(f"{kind} file {dst.relative_to(PROJECT)}")
    assets = PROJECT / "assets"
    refs = {p[k] for p in entries for k in ("asset", "thumb") if k in p}
    old_refs = {p[k] for p in old_entries.values() for k in ("asset", "thumb") if k in p}
    stale = [assets / r for r in sorted(old_refs - refs) if (assets / r).exists()]
    cdn_refs = {p[k] for p in entries for k in ("url", "thumbUrl") if k in p}
    stale += [
        f for folder in (PICTURES, THUMBS) for f in sorted(folder.glob("*.webp"))
        if f"{folder.name}/{f.name}" not in cdn_refs
    ]
    for f in stale:
        print(f"remove file {f.relative_to(PROJECT)}")

    free = sum(1 for p in entries if "asset" in p)
    print(
        f"{len(entries)} puzzles ({free} free), version {old.get('version')} -> {version}; "
        f"entries: {len(added)} added, {len(updated)} updated, {len(removed)} removed; "
        f"files: {len(to_copy)} copied, {len(stale)} removed"
    )
    if args.dry_run:
        print("dry run: nothing written")
        return

    # Copy, then switch the manifest, then delete: a failure never leaves the
    # manifest pointing at a missing file.
    for src, dst, _ in to_copy:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dst)
    write_json(MANIFEST, manifest)
    write_json(CDN_MANIFEST, manifest)
    print(f"wrote {MANIFEST.relative_to(PROJECT)} and {CDN_MANIFEST.relative_to(PROJECT)}")
    for f in stale:
        f.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
