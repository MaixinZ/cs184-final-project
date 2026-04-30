"""Compare every shader output in `figures/` against the original `night.jpg`
and report per-image SSIM scores.

Folder layout expected:

    figures/
        night.jpg          # original (reference)
        <anything>.png     # shader output(s)
        <anything>.jpg     # shader output(s)
        ...

Run:
    python evaluate.py
"""

from pathlib import Path

import cv2
import pandas as pd
from skimage.metrics import structural_similarity as ssim

FIGURES_DIR = Path("figures")
ORIGINAL_NAME = "night.jpg"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".ppm"}


def load_rgb(path: Path):
    img = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if img is None:
        raise RuntimeError(f"Failed to read image: {path}")
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)


def match_size(src, target_shape):
    """Resize `src` to match (H, W) of `target_shape` if needed."""
    h, w = target_shape[:2]
    if src.shape[:2] != (h, w):
        src = cv2.resize(src, (w, h), interpolation=cv2.INTER_AREA)
    return src


def main():
    if not FIGURES_DIR.is_dir():
        raise SystemExit(f"Folder not found: {FIGURES_DIR.resolve()}")

    original_path = FIGURES_DIR / ORIGINAL_NAME
    if not original_path.exists():
        raise SystemExit(f"Original image not found: {original_path}")

    original_rgb = load_rgb(original_path)
    original_gray = cv2.cvtColor(original_rgb, cv2.COLOR_RGB2GRAY)

    rows = []
    for path in sorted(FIGURES_DIR.iterdir()):
        if not path.is_file():
            continue
        if path.name == ORIGINAL_NAME:
            continue
        if path.suffix.lower() not in IMAGE_EXTS:
            continue

        try:
            shader_rgb = load_rgb(path)
        except RuntimeError as err:
            print(err)
            continue

        shader_rgb = match_size(shader_rgb, original_rgb.shape)
        shader_gray = cv2.cvtColor(shader_rgb, cv2.COLOR_RGB2GRAY)

        ssim_color = ssim(
            original_rgb,
            shader_rgb,
            channel_axis=2,
            data_range=255,
        )
        ssim_gray = ssim(
            original_gray,
            shader_gray,
            data_range=255,
        )

        rows.append(
            {
                "image": path.name,
                "ssim_gray": round(float(ssim_gray), 4),
                "ssim_color": round(float(ssim_color), 4),
            }
        )

    if not rows:
        print("No shader images found in", FIGURES_DIR)
        return

    df = pd.DataFrame(rows).sort_values("ssim_gray", ascending=False)
    df.to_csv("ssim_results.csv", index=False)

    print(f"Reference: {original_path}")
    print(df.to_string(index=False))
    print(
        f"\nMean SSIM (gray): {df['ssim_gray'].mean():.4f}"
        f" | Mean SSIM (color): {df['ssim_color'].mean():.4f}"
    )
    print("\nSaved -> ssim_results.csv")


if __name__ == "__main__":
    main()
