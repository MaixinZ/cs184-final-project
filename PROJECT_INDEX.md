# Project Index: CS184 Final Project — NPR Post-Processing Shaders

Generated: 2026-05-02

## Project Structure

```
cs184-final-project/
├── main.cpp              # Entry point — loads shader by name, launches OpenGL viewer
├── parse.cpp/h           # Shader source loader and #include resolver
├── synth.cpp/h           # Procedural texture synthesis (noise, patterns)
├── gui.cpp/h             # ImGui parameter panel + OpenGL window loop
├── texture.cpp/h         # Image loading (stb_image) and GL texture upload
├── constant.cpp/h        # Shared constants (paths, defaults)
├── app_types.h           # Structs: AppConfig, ShaderParams, ViewerState
├── Makefile              # clang++ C++17, links GLFW + GLEW + OpenGL (macOS)
├── fx/                   # ReShade .fx shader sources (HLSL-style)
│   ├── black-ink.fx      # 601 lines — manga/comic NPR
│   ├── celluloid.fx      # 373 lines — cel-shading NPR
│   └── painter.fx        # 175 lines — oil-paint NPR
├── shaders/              # GLSL shader sources (viewer runtime)
│   ├── black-ink.frag    # 528 lines — GLSL port of black-ink
│   ├── celluloid.frag    # 311 lines — GLSL port of celluloid
│   ├── light-accent.frag # 306 lines — light accent post-process
│   ├── painter.frag      #  94 lines — GLSL port of painter
│   └── *.vert            # Pass-through vertex shaders (11-12 lines each)
├── tools/
│   └── profile_ssim.py   # SSIM quality profiling script (numpy, scikit-image)
├── example/              # Demo screenshots and reference images
├── build/ssim_report/    # Generated SSIM analysis outputs
├── report/               # LaTeX report sources (example.tex, work.tex)
├── docs/                 # Pipeline documentation per shader
├── memory/               # Style memory files (shader design context)
├── Papers/               # 5 literature paper notes (Obsidian-style)
├── Knowledge/            # Literature-Overview.md synthesis
└── Maps/                 # literature.canvas (Obsidian JSON canvas)
```

## Entry Points

- **Viewer**: `main.cpp` → `make run` or `make run-debug` — OpenGL window with shader hot-reload
- **SSIM Profiler**: `tools/profile_ssim.py` — measures structural similarity between rendered output and reference
- **Report**: `report/work.tex` — LaTeX final project report

## Core Shaders (3 NPR pipelines)

### black-ink (manga/comic)
- ReShade: `fx/black-ink.fx` (601 lines)
- GLSL: `shaders/black-ink.frag` (528 lines)
- Pipeline: Edge hierarchy → Shadow classification → Black fill → Screentone/Hatching → Ink compositing → Paper finish
- Key functions: `evalViewSilhouette`, `evalDotTone`, `evalHatchPattern`, `evalLinePriority`, `compositeInkLayers`

### celluloid (cel-shading)
- ReShade: `fx/celluloid.fx` (373 lines)
- GLSL: `shaders/celluloid.frag` (311 lines)
- Pipeline: Region smoothing → Pseudo-normal → Cel band quantization → Stylized lighting → Outline → Atmosphere
- Key functions: `EvalPseudoNormal`, `EvalCelBand`, `EvalStylizedSpecular`, `EvalRimMask`, `EvalOutline`

### painter (oil-paint)
- ReShade: `fx/painter.fx` (175 lines)
- GLSL: `shaders/painter.frag` (94 lines)

### light-accent
- GLSL only: `shaders/light-accent.frag` (306 lines)

## C++ Viewer Application

| Module | Lines | Purpose |
|--------|-------|---------|
| `main.cpp` | 46 | CLI arg parsing, shader path resolution, viewer launch |
| `gui.cpp` | 353 | ImGui panel, OpenGL context, render loop |
| `parse.cpp` | 184 | Shader source loading with #include expansion |
| `synth.cpp` | 152 | Procedural noise and pattern generation |
| `texture.cpp` | 100 | Image load (stb_image) → GL texture |
| `constant.cpp` | 62 | Path constants, default parameters |
| `app_types.h` | 200 | Core structs: AppConfig, ShaderParams, ViewerState |

Build: `make release` → `./viewer <style>` (e.g., `./viewer black-ink`)

## Research Knowledge Base

### Papers/ (5 notes)
| File | Paper | Relevance |
|------|-------|-----------|
| `Chen2025-3D-Neural-Stylization-Survey.md` | IJCV survey | Landscape context |
| `Lucena2025-UE5-Cel-Shading.md` | SIGGRAPH Asia poster | Direct parallel to celluloid |
| `Roshaan2026-AHEAD.md` | Preprint | Direct parallel to edge hierarchy |
| `Xie2025-Screentone-Manga-Retargeting.md` | CGF | Domain overlap with screentone |
| `Liu2025-Pencil-Drawing-Simulation.md` | SIVP | Technique overlap with noise |

### Knowledge/
- `Literature-Overview.md` — Full pipeline tables, paper↔shader relevance maps, 7 themes, 5 research gaps

### Maps/
- `literature.canvas` — Obsidian JSON canvas: 2 shader nodes, 6 stage nodes, 5 paper nodes, 4 gap nodes, 19 edges

### docs/
- `black_ink_pipeline.md` — Stage-by-stage pipeline documentation
- `celluloid_pipeline.md` — Stage-by-stage pipeline documentation
- `light_accent_pipeline.md` — Light accent pipeline documentation
- `ssim_profile.md` — SSIM profiling methodology and results

### memory/
- `black-ink.md`, `celluloid.md`, `painter.md` — Per-shader design context and constraints

## Dependencies

- **C++**: clang++ (C++17), GLFW, GLEW, OpenGL (macOS frameworks)
- **Python**: numpy, pillow, scikit-image (for SSIM profiling)
- **Build**: Make
- **Vendor**: `stb_image.h` (header-only image loader, 7988 lines)

## Quick Start

```bash
make release        # Build the viewer
./viewer black-ink  # Run with manga shader
./viewer celluloid  # Run with cel shader
./viewer painter    # Run with oil-paint shader
```

## Codebase Stats

- Total shader lines: ~2,388 (fx + GLSL)
- Total C++ lines: ~897 (excluding stb_image)
- Paper notes: 5
- Example images: 12
