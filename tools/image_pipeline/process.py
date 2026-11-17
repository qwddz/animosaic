"""Turns accepted pictures into app assets.

For every selected/<id>.png: center crop to 4:3, Lanczos resize to 2048x1536,
WebP q85, a 400x300 preview and a blurred preview for locked pictures.
Hashes and sizes go to processed/index.json.

    uv run process.py
    uv run process.py --id farm_pig
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter

from common import PROCESSED, SELECTED, load_animals, select

SIZE = (2048, 1536)
PREVIEW = (400, 300)
QUALITY = 85
BLUR_RADIUS = 12


def crop_4_3(image: Image.Image) -> Image.Image:
    w, h = image.size
    if w * 3 > h * 4:  # wider than 4:3
        cw, ch = round(h * 4 / 3), h
    else:
        cw, ch = w, round(w * 3 / 4)
    left, top = (w - cw) // 2, (h - ch) // 2
    return image.crop((left, top, left + cw, top + ch))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_image(src: Path, out: Path, id: str) -> dict:
    """Writes <out>/<id>.webp, <out>/preview/<id>.webp, <out>/preview_blur/<id>.webp."""
    for sub in ("", "preview", "preview_blur"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    source = Image.open(src).convert("RGB")
    cropped = crop_4_3(source)
    full = cropped.resize(SIZE, Image.Resampling.LANCZOS)
    preview = cropped.resize(PREVIEW, Image.Resampling.LANCZOS)
    blurred = preview.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))

    paths = {
        "image": out / f"{id}.webp",
        "preview": out / "preview" / f"{id}.webp",
        "preview_blur": out / "preview_blur" / f"{id}.webp",
    }
    full.save(paths["image"], "WEBP", quality=QUALITY, method=6)
    preview.save(paths["preview"], "WEBP", quality=QUALITY, method=6)
    blurred.save(paths["preview_blur"], "WEBP", quality=QUALITY, method=6)
    return {
        "source": f"{source.width}x{source.height}",
        "upscale": round(SIZE[1] / cropped.height, 2),
        **{
            name: {"sha256": sha256(path), "bytes": path.stat().st_size}
            for name, path in paths.items()
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--id", action="append", default=[], help="picture id, repeatable")
    args = parser.parse_args()

    animals = select(load_animals(), args.id, None)
    todo = [a for a in animals if (SELECTED / f"{a.id}.png").exists()]
    if not todo:
        print("selected/ has nothing to process")
        return

    index_path = PROCESSED / "index.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    for a in todo:
        info = process_image(SELECTED / f"{a.id}.png", PROCESSED, a.id)
        index[a.id] = info
        kb = info["image"]["bytes"] // 1024
        print(f"{a.id}: {info['source']} -> {SIZE[0]}x{SIZE[1]} (x{info['upscale']}), {kb} KB")
    index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
