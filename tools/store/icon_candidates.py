"""Generates app icon candidates with Nano Banana 2 Lite in the game's art style.

    ../image_pipeline/.venv/bin/python icon_candidates.py

Writes tools/store/icons/<name>.png (1:1). Costs about $0.045 per image.
"""

import io
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "image_pipeline"))
from common import STYLE_ANCHOR, load_env  # noqa: E402

from PIL import Image  # noqa: E402

STYLE = (
    "Create a mobile app icon in the same art style as the reference image: "
    "bold dark outlines, smooth cartoon shading, bright saturated colors, big "
    "expressive cartoon eyes, children's book style. Take only the art style "
    "from the reference. The design fills the whole square, centered, simple "
    "and readable at small size, few large shapes, a plain bright background "
    "color, no text, no letters, no frame, no border, no rounded corners, no "
    "drop shadow outside the subject."
)

CONCEPTS = {
    "fox_pieces": "A cute smiling red fox face assembled from four big jigsaw puzzle pieces, one piece slightly lifted, on a warm yellow background.",
    "turtle_piece": "A cute smiling green sea turtle peeking out of one big jigsaw puzzle piece, on a turquoise background.",
    "lion_piece": "A cute smiling lion cub head on top of a large orange jigsaw puzzle piece shape, on a sky blue background.",
    "mosaic_four": "A 2 by 2 mosaic of four rounded jigsaw tiles, each with a cute animal face: fox, turtle, elephant, owl, slightly separated, on a soft green background.",
}


def main() -> None:
    load_env()
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    out = HERE / "icons"
    out.mkdir(exist_ok=True)
    anchor = Image.open(STYLE_ANCHOR)
    config = types.GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=types.ImageConfig(aspect_ratio="1:1"),
    )
    for name, subject in CONCEPTS.items():
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-image",
            contents=[f"{STYLE}\nSubject: {subject}", anchor],
            config=config,
        )
        data = [p.inline_data.data for p in response.parts or [] if p.inline_data and not p.thought]
        if not data:
            print(f"{name}: no image")
            continue
        image = Image.open(io.BytesIO(data[-1])).convert("RGB")
        image.save(out / f"{name}.png")
        print(f"{name}: {image.size}")


if __name__ == "__main__":
    main()
