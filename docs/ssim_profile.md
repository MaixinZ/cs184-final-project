# SSIM Image-Pair Experiment

This project uses SSIM as a structure-preservation check for finished shader images. SSIM is not an artistic-quality score. It does not know whether an image looks like good cel animation, manga ink, or pleasing non-photorealistic rendering. It only compares local luminance, contrast, and structure between a reference image and a shader output.

The experiment script is now image-pair based. It does not build the viewer, launch `./viewer`, render shader outputs, or manage export timeouts. It compares existing files in `example/` and writes a local report under `build/ssim_report/`.

Install the Python dependencies first:

```sh
python3 -m pip install -r requirements.txt
```

## Default Command

Run the default experiment from the repository root:

```sh
python3 tools/profile_ssim.py --ref example/reference.jpg --out build/ssim_report
```

The default reference is `example/reference.jpg`. The default shader-output pairs are:

| Shader | Output |
| --- | --- |
| `Black-Ink` | `example/black-int.png` |
| `Cel` | `example/cel.png` |
| `Pixel` | `example/pixel.png` |
| `Oil Painting` | `example/oil-paint.png` |
| `RedGreen` | `example/red-green.png` |

The `Black-Ink` display name is canonical even though the current example filename is `black-int.png`.

## Explicit Pairs

Pass `--pair "Name=path"` to compare a smaller or custom set:

```sh
python3 tools/profile_ssim.py --ref example/reference.jpg --pair "Cel=example/cel.png" --pair "Pixel=example/pixel.png"
```

When explicit pairs are provided, they replace the default five-pair set.

## Metrics

The script uses `skimage.metrics.structural_similarity` for both reported metrics:

- `luminance_ssim`: SSIM after converting RGB to Rec.709 luminance with `Y = 0.2126R + 0.7152G + 0.0722B`. This is the primary structure-preservation metric.
- `rgb_ssim`: SSIM on RGB data with `channel_axis=-1`. This is color-sensitive and can drop when a shader intentionally shifts or removes color.

The example resources mix `1495x840` and `2560x1440` outputs. The script therefore center-crops and resizes `example/reference.jpg` separately for each shader output's actual size before computing SSIM. It also writes one normalized reference preview per encountered size.

## Output Files

The default command writes:

- `build/ssim_report/ssim_results.json`: machine-readable metrics
- `build/ssim_report/ssim_results.md`: Markdown table for reports or notes
- `build/ssim_report/reference_<width>x<height>.png`: normalized reference previews used for comparison

The `width` and `height` fields in the JSON and Markdown output are the actual comparison size for each shader output.

## Interpretation

Use `luminance_ssim` as the main check that major forms, edges, and tonal regions survived the stylization pass. Read it together with the output image instead of treating the number as a standalone quality judgment.

`rgb_ssim` is intentionally stricter about color. Black-Ink may score lower on RGB SSIM because it removes color by design. A monochrome ink render can be visually successful while scoring poorly on RGB similarity.

## Self-Test

The script includes a self-test for the image-comparison path:

```sh
python3 tools/profile_ssim.py --self-test
```

It checks that identical synthetic images score near `1.0`, altered synthetic image pairs score lower, both luminance and RGB metrics call `skimage.metrics.structural_similarity`, and reference resizing handles `1495x840` and `2560x1440`.
