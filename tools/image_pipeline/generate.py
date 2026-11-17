"""Generates one variant per picture with Nano Banana 2 Lite.

Pictures already accepted (selected/) or waiting for review (raw/) are skipped,
so running it again only regenerates rejected pictures.

    uv run generate.py                      # every row of animals.csv
    uv run generate.py --category sea
    uv run generate.py --id farm_pig --id sea_turtle
    uv run generate.py --dry-run            # print prompts, no API calls
    uv run generate.py --budget 9 --workers 4

Free pictures (order <= 5) go first, so a run stopped by the budget leaves
every category with its free set. Spend is estimated from token usage at list
prices and summed in state.json; compare it with the real billing.
"""

import argparse
import io
import json
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

from PIL import Image

from common import (
    ANCHORS,
    PIPELINE,
    RAW,
    SELECTED,
    STYLE_ANCHOR,
    Animal,
    load_animals,
    load_env,
    load_state,
    save_state,
    select,
)

MODEL = "gemini-3.1-flash-lite-image"
ATTEMPTS = 3

# List prices, USD per token: input, output image, output text and thoughts.
PRICE_INPUT = 0.25e-6
PRICE_OUTPUT_IMAGE = 30e-6  # $0.0336 per 1K image of ~1120 tokens
PRICE_OUTPUT_TEXT = 1.50e-6
# Real billing came out 1.26x the token estimate (2026-11-13: ~$11.3 billed
# for 261 pictures estimated at $8.98), so estimates are scaled by it.
BILLING_FACTOR = 1.26
# Reserved per request in flight when checking the budget.
RESERVE_PER_IMAGE = 0.045

CATEGORY_HINT = (
    "The first reference image defines the art style. The second reference "
    "image is from the same picture series: match its background style, "
    "palette and level of detail, but draw a new scene."
)


def build_prompt(animal: Animal, with_category_anchor: bool) -> str:
    template = (PIPELINE / "prompt.txt").read_text(encoding="utf-8")
    prompt = template.format(
        animal=animal.animal, habitat=animal.habitat, scene=animal.scene
    ).strip()
    if with_category_anchor:
        prompt += "\n" + CATEGORY_HINT
    return prompt


def category_anchor(animal: Animal):
    path = ANCHORS / f"{animal.category}.png"
    return path if path.exists() else None


def cost_of(usage) -> tuple[float, dict]:
    """Estimated USD cost of one response and the token counts behind it."""
    if usage is None:
        return RESERVE_PER_IMAGE, {}
    image_out = sum(
        d.token_count or 0
        for d in usage.candidates_tokens_details or []
        if str(d.modality).endswith("IMAGE")
    )
    other_out = (usage.candidates_token_count or 0) - image_out + (usage.thoughts_token_count or 0)
    tokens = {
        "input": usage.prompt_token_count or 0,
        "output_image": image_out,
        "output_other": other_out,
    }
    cost = BILLING_FACTOR * (
        tokens["input"] * PRICE_INPUT
        + image_out * PRICE_OUTPUT_IMAGE
        + other_out * PRICE_OUTPUT_TEXT
    )
    return cost, tokens


def generate_one(client, types, errors, animal: Animal) -> tuple[Image.Image | None, float]:
    anchor = category_anchor(animal)
    prompt = build_prompt(animal, anchor is not None)
    contents = [prompt, Image.open(STYLE_ANCHOR)]
    if anchor is not None:
        contents.append(Image.open(anchor))
    config = types.GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=types.ImageConfig(aspect_ratio="4:3"),
    )
    spent = 0.0
    for attempt in range(1, ATTEMPTS + 1):
        try:
            response = client.models.generate_content(
                model=MODEL, contents=contents, config=config
            )
        except errors.APIError as error:
            print(f"  {animal.id} attempt {attempt}: {error}", file=sys.stderr)
            # Only rate limits and server errors can pass on their own.
            if error.code != 429 and error.code < 500:
                return None, spent
            if attempt < ATTEMPTS:
                time.sleep((30 if error.code == 429 else 5) * attempt)
            continue
        except Exception as error:  # network (httpx) and other transient failures
            print(f"  {animal.id} attempt {attempt}: {error}", file=sys.stderr)
            if attempt < ATTEMPTS:
                time.sleep(5 * attempt)
            continue
        cost, tokens = cost_of(response.usage_metadata)
        spent += cost
        # Draft "thought" images may precede the final one; take the last real image.
        images = [
            p.inline_data.data
            for p in response.parts or []
            if p.inline_data and p.inline_data.data and not p.thought
        ]
        if images:
            image = Image.open(io.BytesIO(images[-1]))
            image.load()
            _write_meta(animal, prompt, anchor, tokens, cost)
            return image, spent
        # No image usually means the request was blocked; retrying rarely helps.
        reason = response.candidates[0].finish_reason if response.candidates else None
        print(f"  {animal.id}: no image in response: {reason or response.prompt_feedback or response.text}", file=sys.stderr)
        return None, spent
    return None, spent


def _write_meta(animal: Animal, prompt: str, anchor, tokens: dict, cost: float) -> None:
    meta = {
        "model": MODEL,
        "prompt": prompt,
        "references": [STYLE_ANCHOR.name] + ([anchor.name] if anchor else []),
        "tokens": tokens,
        "estimated_usd": round(cost, 5),
        "created": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    (RAW / f"{animal.id}.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--id", action="append", default=[], help="picture id, repeatable")
    parser.add_argument("--category", help="only this category")
    parser.add_argument("--dry-run", action="store_true", help="print prompts without calling the API")
    parser.add_argument("--budget", type=float, default=1.0, help="max estimated USD for this run (default 1)")
    parser.add_argument("--workers", type=int, default=1, help="parallel requests (default 1)")
    args = parser.parse_args()

    animals = select(load_animals(), args.id, args.category)
    todo = sorted(
        (
            a
            for a in animals
            if not (SELECTED / f"{a.id}.png").exists() and not (RAW / f"{a.id}.png").exists()
        ),
        key=lambda a: (not a.free, a.order, a.category),
    )
    print(f"{len(todo)} to generate, {len(animals) - len(todo)} skipped (accepted or awaiting review)")
    if not todo:
        return

    if args.dry_run:
        for a in todo:
            anchor = category_anchor(a)
            print(f"\n--- {a.id} (references: {STYLE_ANCHOR.name}{', ' + anchor.name if anchor else ''})")
            print(build_prompt(a, anchor is not None))
        return

    load_env()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise SystemExit("GEMINI_API_KEY is not set: add it to the project .env")

    from google import genai
    from google.genai import errors, types

    client = genai.Client(api_key=key)
    RAW.mkdir(exist_ok=True)
    lock = threading.Lock()
    run = {"spent": 0.0, "in_flight": 0, "done": 0, "stopped": False}
    failed = []

    def work(animal: Animal) -> None:
        with lock:
            reserve = (run["in_flight"] + 1) * RESERVE_PER_IMAGE
            if run["stopped"] or run["spent"] + reserve > args.budget:
                run["stopped"] = True
                return
            run["in_flight"] += 1
        image, cost = generate_one(client, types, errors, animal)
        if image is not None:
            image.convert("RGB").save(RAW / f"{animal.id}.png")
        with lock:
            run["in_flight"] -= 1
            run["spent"] += cost
            run["done"] += 1
            state = load_state()
            state["spent_usd"] = round(state.get("spent_usd", 0.0) + cost, 5)
            save_state(state)
            if image is None:
                failed.append(animal.id)
                print(f"[{run['done']}/{len(todo)}] {animal.id} FAILED")
            else:
                print(f"[{run['done']}/{len(todo)}] {animal.id} {image.width}x{image.height} ${cost:.4f}, run ${run['spent']:.2f}")

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        list(pool.map(work, todo))

    left = len(todo) - run["done"]
    print(f"run: {run['done']} requests, estimated ${run['spent']:.2f}; total in state.json ${load_state().get('spent_usd', 0):.2f}")
    if run["stopped"] and left:
        print(f"budget ${args.budget:.2f} reached: {left} pictures left for the next run")
    if failed:
        raise SystemExit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
