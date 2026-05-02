#!/usr/bin/env python3
"""Compare shader image outputs against a reference image with SSIM."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, UnidentifiedImageError

try:
    from skimage.metrics import structural_similarity
except ImportError as exc:
    structural_similarity = None
    SKIMAGE_IMPORT_ERROR = exc
else:
    SKIMAGE_IMPORT_ERROR = None


REC709 = np.array([0.2126, 0.7152, 0.0722], dtype=np.float64)
DEFAULT_REFERENCE = Path("example/reference.jpg")
DEFAULT_PAIRS: tuple[tuple[str, Path], ...] = (
    ("Black-Ink", Path("example/black-int.png")),
    ("Cel", Path("example/cel.png")),
    ("Pixel", Path("example/pixel.png")),
    ("Oil Painting", Path("example/oil-paint.png")),
    ("RedGreen", Path("example/red-green.png")),
)
DEFAULT_OUT_DIR = Path("build/ssim_report")

try:
    RESAMPLE_LANCZOS = Image.Resampling.LANCZOS
except AttributeError:
    RESAMPLE_LANCZOS = Image.LANCZOS


class ProfileError(RuntimeError):
    """Raised for expected profile-script failures."""


def parse_pair(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("expected NAME=PATH")

    name, path = value.split("=", 1)
    name = name.strip()
    path = path.strip()
    if not name:
        raise argparse.ArgumentTypeError("pair name cannot be empty")
    if not path:
        raise argparse.ArgumentTypeError("pair image path cannot be empty")
    return name, Path(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute luminance and RGB SSIM for reference/output image pairs."
    )
    parser.add_argument(
        "--ref",
        default=str(DEFAULT_REFERENCE),
        help=f"Reference image path. Default: {DEFAULT_REFERENCE}",
    )
    parser.add_argument(
        "--pair",
        action="append",
        type=parse_pair,
        metavar="NAME=PATH",
        help="Shader output pair. Repeat to compare multiple explicit outputs.",
    )
    parser.add_argument(
        "--out",
        default=str(DEFAULT_OUT_DIR),
        help=f"Report output directory. Default: {DEFAULT_OUT_DIR}",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run internal image-comparison checks, then exit.",
    )
    return parser.parse_args()


def ensure_skimage_available() -> None:
    if structural_similarity is None:
        raise ProfileError(
            "Missing Python dependency 'scikit-image'. Install dependencies with "
            "`python3 -m pip install -r requirements.txt` and rerun this script. "
            f"Import error: {SKIMAGE_IMPORT_ERROR}"
        )


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def resolve_repo_path(path: Path, root: Path) -> Path:
    if path.is_absolute():
        return path
    return root / path


def image_size(path: Path) -> tuple[int, int]:
    try:
        with Image.open(path) as image:
            return image.size
    except FileNotFoundError as exc:
        raise ProfileError(f"Image not found: {path}") from exc
    except UnidentifiedImageError as exc:
        raise ProfileError(f"Could not read image file: {path}") from exc


def ensure_rgb_array(image: np.ndarray) -> np.ndarray:
    arr = np.asarray(image, dtype=np.float64)
    if arr.ndim != 3 or arr.shape[2] != 3:
        raise ValueError(f"Expected an RGB image array, got shape {arr.shape}.")
    return arr


def image_to_rgb_float(image: Image.Image) -> np.ndarray:
    return np.asarray(image.convert("RGB"), dtype=np.float64) / 255.0


def load_rgb_float(path: Path) -> np.ndarray:
    try:
        with Image.open(path) as image:
            return image_to_rgb_float(image)
    except FileNotFoundError as exc:
        raise ProfileError(f"Image not found: {path}") from exc
    except UnidentifiedImageError as exc:
        raise ProfileError(f"Could not read image file: {path}") from exc


def center_crop_to_aspect(image: Image.Image, width: int, height: int) -> Image.Image:
    source_width, source_height = image.size
    target_aspect = width / height
    source_aspect = source_width / source_height

    if source_aspect > target_aspect:
        crop_width = int(round(source_height * target_aspect))
        left = (source_width - crop_width) // 2
        box = (left, 0, left + crop_width, source_height)
    else:
        crop_height = int(round(source_width / target_aspect))
        top = (source_height - crop_height) // 2
        box = (0, top, source_width, top + crop_height)
    return image.crop(box)


def prepare_reference_image(reference_path: Path, target_size: tuple[int, int]) -> Image.Image:
    width, height = target_size
    if width <= 0 or height <= 0:
        raise ValueError(f"Target size must be positive, got {width}x{height}.")

    try:
        with Image.open(reference_path) as image:
            rgb = image.convert("RGB")
            cropped = center_crop_to_aspect(rgb, width, height)
            return cropped.resize((width, height), RESAMPLE_LANCZOS)
    except FileNotFoundError as exc:
        raise ProfileError(f"Reference image not found: {reference_path}") from exc
    except UnidentifiedImageError as exc:
        raise ProfileError(f"Could not read reference image file: {reference_path}") from exc


def luminance(image: np.ndarray) -> np.ndarray:
    return np.tensordot(ensure_rgb_array(image), REC709, axes=([-1], [0]))


def skimage_ssim(reference: np.ndarray, candidate: np.ndarray, **kwargs: object) -> float:
    ensure_skimage_available()
    ref = np.asarray(reference, dtype=np.float64)
    cand = np.asarray(candidate, dtype=np.float64)
    if ref.shape != cand.shape:
        raise ValueError(f"SSIM inputs must have matching shapes, got {ref.shape} and {cand.shape}.")
    return float(structural_similarity(ref, cand, data_range=1.0, **kwargs))


def compute_luminance_ssim(reference: np.ndarray, candidate: np.ndarray) -> float:
    return skimage_ssim(luminance(reference), luminance(candidate))


def compute_rgb_ssim(reference: np.ndarray, candidate: np.ndarray) -> float:
    ref = ensure_rgb_array(reference)
    cand = ensure_rgb_array(candidate)
    return skimage_ssim(ref, cand, channel_axis=-1)


def reference_preview_path(out_dir: Path, size: tuple[int, int]) -> Path:
    width, height = size
    return out_dir / f"reference_{width}x{height}.png"


def compare_pair(
    name: str,
    reference_path: Path,
    output_path: Path,
    out_dir: Path,
) -> dict[str, object]:
    size = image_size(output_path)
    normalized_reference = prepare_reference_image(reference_path, size)
    preview_path = reference_preview_path(out_dir, size)
    normalized_reference.save(preview_path)

    reference_array = image_to_rgb_float(normalized_reference)
    output_array = load_rgb_float(output_path)

    return {
        "style": name,
        "output": str(output_path),
        "normalized_reference": str(preview_path),
        "width": size[0],
        "height": size[1],
        "luminance_ssim": compute_luminance_ssim(reference_array, output_array),
        "rgb_ssim": compute_rgb_ssim(reference_array, output_array),
    }


def selected_pairs(args: argparse.Namespace) -> tuple[tuple[str, Path], ...]:
    if args.pair:
        return tuple(args.pair)
    return DEFAULT_PAIRS


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict[str, object]) -> None:
    lines = [
        "# SSIM Image-Pair Results",
        "",
        f"- Reference: `{payload['reference']}`",
        f"- Output directory: `{payload['out_dir']}`",
        "",
        "| Shader | Size | Luminance SSIM | RGB SSIM | Output | Normalized Reference |",
        "| --- | ---: | ---: | ---: | --- | --- |",
    ]
    for result in payload["results"]:
        lines.append(
            f"| `{result['style']}` | `{result['width']}x{result['height']}` | "
            f"{result['luminance_ssim']:.6f} | {result['rgb_ssim']:.6f} | "
            f"`{result['output']}` | `{result['normalized_reference']}` |"
        )
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def run_profile(args: argparse.Namespace) -> None:
    ensure_skimage_available()

    root = repo_root()
    reference_path = resolve_repo_path(Path(args.ref), root)
    out_dir = resolve_repo_path(Path(args.out), root)
    pairs = tuple(
        (name, resolve_repo_path(path, root))
        for name, path in selected_pairs(args)
    )

    image_size(reference_path)
    for _, output_path in pairs:
        image_size(output_path)

    out_dir.mkdir(parents=True, exist_ok=True)
    results = [
        compare_pair(name, reference_path, output_path, out_dir)
        for name, output_path in pairs
    ]

    payload: dict[str, object] = {
        "reference": str(reference_path),
        "out_dir": str(out_dir),
        "results": results,
    }
    write_json(out_dir / "ssim_results.json", payload)
    write_markdown(out_dir / "ssim_results.md", payload)


def assert_close_to_one(value: float, label: str) -> None:
    if not 0.999999 <= value <= 1.000001:
        raise AssertionError(f"{label} expected near 1.0, got {value}.")


def run_self_test() -> None:
    ensure_skimage_available()

    base = np.zeros((48, 64, 3), dtype=np.float64)
    base[:, :, 0] = np.linspace(0.0, 1.0, base.shape[1])
    base[:, :, 1] = np.linspace(0.0, 1.0, base.shape[0])[:, None]
    base[:, :, 2] = 0.25

    identical_luma = compute_luminance_ssim(base, base.copy())
    identical_rgb = compute_rgb_ssim(base, base.copy())
    assert_close_to_one(identical_luma, "Identical luminance SSIM")
    assert_close_to_one(identical_rgb, "Identical RGB SSIM")

    altered = base.copy()
    altered[12:36, 20:44, :] = 1.0 - altered[12:36, 20:44, :]
    altered_luma = compute_luminance_ssim(base, altered)
    altered_rgb = compute_rgb_ssim(base, altered)
    if not altered_luma < identical_luma:
        raise AssertionError("Altered luminance pair did not score lower than identical pair.")
    if not altered_rgb < identical_rgb:
        raise AssertionError("Altered RGB pair did not score lower than identical pair.")

    calls: list[dict[str, object]] = []
    original_metric = structural_similarity

    def recording_metric(*args: object, **kwargs: object) -> float:
        calls.append(dict(kwargs))
        return 0.5

    try:
        globals()["structural_similarity"] = recording_metric
        if compute_luminance_ssim(base, base) != 0.5:
            raise AssertionError("Luminance SSIM did not use skimage structural_similarity.")
        if compute_rgb_ssim(base, base) != 0.5:
            raise AssertionError("RGB SSIM did not use skimage structural_similarity.")
    finally:
        globals()["structural_similarity"] = original_metric

    if not calls or calls[0].get("channel_axis") is not None:
        raise AssertionError("Luminance SSIM should call skimage without channel_axis.")
    if not any(call.get("channel_axis") == -1 for call in calls):
        raise AssertionError("RGB SSIM should call skimage with channel_axis=-1.")

    with tempfile.TemporaryDirectory() as temp_name:
        temp_dir = Path(temp_name)
        reference_path = temp_dir / "reference.jpg"
        Image.new("RGB", (3840, 2160), color=(128, 96, 64)).save(reference_path)
        for size in [(1495, 840), (2560, 1440)]:
            resized = prepare_reference_image(reference_path, size)
            if resized.size != size:
                raise AssertionError(f"Reference resize returned {resized.size}, expected {size}.")

    print("profile_ssim self-test passed")


def main() -> int:
    args = parse_args()
    try:
        if args.self_test:
            run_self_test()
        else:
            run_profile(args)
    except (ProfileError, OSError, ValueError, AssertionError) as exc:
        print(f"profile_ssim: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
