---
title: NPR Literature Overview
type: synthesis
last_updated: 2026-05-02
paper_count: 5
---

# NPR Literature Overview

## Scope

Literature survey for the CS184 final project — two NPR post-processing shaders:

1. **`black-ink`** — monochrome manga/comic renderer. Converts 3D-rendered frames into black-and-white comic art via edge detection, shadow classification, screentone/hatching, and ink compositing.
2. **`celluloid`** — color cel-shading approximation. Emulates hand-authored animation cels via pseudo-normal reconstruction, grouped cel bands, stylized specular/rim, screen-space outlines, and atmospheric fog.

Both operate as framebuffer-only post-processing passes without access to geometry buffers.

---

## Source Implementation — `black-ink` Shader

| Pipeline Stage | Shader Function | Technique |
|---|---|---|
| Edge extraction | `evalViewSilhouette`, `evalCreaseLine`, `evalContactEdge` | Sobel gradient field on luma + alpha neighborhood |
| Pseudo-normal | `evalPseudoNormal` | Luma gradient → surface normal surrogate |
| Light classification | `evalLightFacingness` | N·L with multi-threshold shadow/mid/highlight |
| Shadow grouping | `classifyShadowRegion` | Light-facingness + cavity + darkness |
| Black fill | `evalBlackFillMask` | Deep shadow collapse → solid black masses (manga beta-nuri) |
| Screentone | `evalDotTone` | Irregular clustered micro-dots with smudge + paper erosion |
| Hatching | `evalHatchPattern`, `evalCrossHatchPattern` | Directional stripe patterns, density-driven |
| Line priority | `evalLinePriority` | Weighted silhouette > contact > crease hierarchy |
| Tone suppression | `evalToneEdgeSuppression` | Damps screentone near strong edges |
| Ink compositing | `compositeInkLayers` | Priority-based layering of fill + tone + line |
| Paper finish | `applyPaperAndPrintFinish` | Paper whiteness + ink spread simulation |

Source files: `fx/black-ink.fx` (ReShade), `shaders/black-ink.frag` (GLSL viewer)

## Source Implementation — `celluloid` Shader

| Pipeline Stage | Shader Function | Technique |
|---|---|---|
| Region smoothing | `SampleRegionAverage` | 3×3 weighted kernel (center×4 + cross + diag) |
| Gradient estimation | `EvalLumaGradient` | Central Difference / Sobel / Scharr selectable |
| Pseudo-normal | `EvalPseudoNormal` | `normalize(-lumaGradient * 3.2, 1.0)` |
| Shade signal | (inline in PS) | `lerp(smoothLuma, ndotl, 0.62) + 0.10` |
| Cel band quantization | `EvalCelBand`, `EvalBandIndex` | 4-band smoothstep: shadow → mid → light → highlight |
| Cel diffuse | `EvalCelDiffuse` | Warm/cool tint per band (shadow=blue, mid=neutral, light=warm) |
| Stylized shadow | `EvalStylizedShadow` | Broad shadow + cavity composite |
| Ambient hemisphere | `EvalAmbientHemisphere` | Sky/ground color blend by pseudo-normal Y |
| Stylized specular | `EvalStylizedSpecular` | Blinn-Phong half-vector with `SpecThreshold` gate |
| Rim light | `EvalRimMask` | Pseudo-Fresnel with `RimThreshold`, shadow/edge modulation |
| Outline extraction | `EvalOutline` | Luma gradient × 2.2 + chroma edge × 1.35, smoothstep gate |
| Fog proxy | `EvalFogFactor`, `ApplyAtmosphere` | Detail-mask distance proxy + screen-space sky bias |
| Tonemapping | `ApplyBandPreservingTonemap` | Shoulder compression preserving band structure |

Source files: `fx/celluloid.fx` (ReShade), `shaders/celluloid.frag` (GLSL viewer)

---

## Papers by Topic

### Hierarchical Edge Detection for NPR
- [[Papers/Roshaan2026-AHEAD|Roshaan 2026]] — AHEAD: three-layer hierarchy (Silhouette/Structure/Texture) for real-time artistic stylization

### Noise-Based Stroke Generation
- [[Papers/Liu2025-Pencil-Drawing-Simulation|Liu et al. 2025]] — Pencil drawing via improved hybrid noise

### Screentone Synthesis & Preservation
- [[Papers/Xie2025-Screentone-Manga-Retargeting|Xie et al. 2025]] — Screentone-preserved manga retargeting with hierarchical grid anchors

### Engine-Integrated Cel Shading
- [[Papers/Lucena2025-UE5-Cel-Shading|Lucena et al. 2025]] — Engine-integrated cel-shading for UE5 via shading model replacement with smoothstep bands

### NPR Survey & Landscape
- [[Papers/Chen2025-3D-Neural-Stylization-Survey|Chen et al. 2025]] — Advances in 3D Neural Stylization: comprehensive taxonomy of neural NPR methods

---

## Paper ↔ Shader Relevance Map

### black-ink Relevance

| Paper | Relevant Stages | Relationship |
|---|---|---|
| Roshaan 2026 (AHEAD) | Edge extraction, line priority | **Direct parallel** — both use layered edge hierarchies for post-processing NPR. AHEAD's Silhouette/Structure/Texture layers map to black-ink's silhouette/crease/contact decomposition. |
| Liu 2025 (Pencil) | Screentone, paper grain | **Technique overlap** — hybrid noise parallels black-ink's `valueNoise`-based micro-dot clustering and paper grain. |
| Xie 2025 (Screentone) | Screentone, hatching | **Domain overlap** — screentone representation for manga. Hierarchical grid anchors relate to black-ink's grid-based dot spacing. |

### celluloid Relevance

| Paper | Relevant Stages | Relationship |
|---|---|---|
| Lucena 2025 (UE5 Cel) | Cel band quantization, cel diffuse, specular | **Direct parallel** — both use smoothstep band transitions for cel illumination. Lucena integrates into deferred pipeline; celluloid approximates from framebuffer. |
| Roshaan 2026 (AHEAD) | Outline extraction | **Technique overlap** — both extract edges from image-space for NPR contour rendering. AHEAD's multi-layer hierarchy could replace celluloid's single-threshold outline. |
| Chen 2025 (Survey) | Contextual | **Landscape context** — positions celluloid's procedural approach against neural alternatives. Highlights that procedural methods retain real-time speed and fine-grained control advantages. |

### Cross-Shader Shared Relevance

| Technique | black-ink | celluloid | Shared Paper |
|---|---|---|---|
| Pseudo-normal from luma gradient | `evalPseudoNormal` | `EvalPseudoNormal` | — (no dedicated paper; both derive from Winnemöller 2006 video abstraction principles) |
| Screen-space edge detection | `evalViewSilhouette` etc. | `EvalOutline` | Roshaan 2026 (AHEAD) |
| Smoothstep-based thresholding | Shadow/mid/highlight gates | `EvalCelBand` 4-band | Lucena 2025 (UE5 Cel) |

---

## Key Themes

1. **Layered edge hierarchy** — Decomposing edges into semantic layers for priority-driven compositing
2. **Procedural noise for mark-making** — Value noise, smudge, paper erosion for organic stroke appearance
3. **Screentone as tonal language** — Dot/hatch patterns as manga-specific shadow representation
4. **Post-processing NPR** — Image-space stylization without geometry buffers (framebuffer-only surrogate)
5. **Smoothstep cel banding** — Quantized illumination with soft transitions for stylized shading
6. **Engine-integrated vs. post-process NPR** — Tradeoff between pipeline access (Lucena) and portability (celluloid/black-ink)
7. **Neural vs. procedural NPR** — Learned methods offer style diversity; procedural methods offer real-time speed and artist control

## Research Gaps

- Real-time screentone synthesis with learned density maps (Xie's approach is offline)
- Depth-aware edge hierarchy (AHEAD uses depth; both shaders currently use luma-only proxy)
- Temporal coherence for animated manga rendering with stable screentone
- Multi-light cel shading from image-space (celluloid has single virtual light; Lucena shows multi-light requires engine access)
- Hybrid neural-procedural NPR for combining style diversity with real-time performance

## Collection Status

| Source | Coverage |
|--------|----------|
| Zotero NPR | 5 / 5 (Liu, Roshaan, Xie, Lucena, Chen) |
| Local Papers/ | 5 / 5 |
