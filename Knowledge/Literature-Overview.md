---
title: NPR Literature Overview
type: synthesis
last_updated: 2026-04-29
paper_count: 3
---

# NPR Literature Overview

## Scope

Literature survey for the CS184 final project — a monochrome manga/comic NPR renderer (`black-ink` style). The shader pipeline converts 3D-rendered frames into black-and-white comic art via post-processing edge detection, shadow classification, screentone/hatching, and ink compositing.

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

## Papers by Topic

### Hierarchical Edge Detection for NPR
- [[Papers/Roshaan2026-AHEAD|Roshaan 2026]] - AHEAD: three-layer hierarchy (Silhouette/Structure/Texture) for real-time artistic stylization

### Noise-Based Stroke Generation
- [[Papers/Liu2025-Pencil-Drawing-Simulation|Liu et al. 2025]] - Pencil drawing via improved hybrid noise

### Screentone Synthesis & Preservation
- [[Papers/Xie2025-Screentone-Manga-Retargeting|Xie et al. 2025]] - Screentone-preserved manga retargeting with hierarchical grid anchors

## Paper ↔ Shader Relevance Map

| Paper | Relevant Shader Stages | Relationship |
|---|---|---|
| Roshaan 2026 (AHEAD) | Edge extraction, line priority, silhouette/structure/texture split | **Direct parallel** — both use layered edge hierarchies for post-processing NPR. AHEAD's Silhouette/Structure/Texture layers map to black-ink's silhouette/crease/contact decomposition. Both use max-pooling/priority fusion. |
| Liu 2025 (Pencil) | Screentone (dot tone), paper grain | **Technique overlap** — hybrid noise for stroke texture generation parallels black-ink's `valueNoise`-based micro-dot clustering and paper grain. |
| Xie 2025 (Screentone) | Screentone (dot tone, hatch) | **Domain overlap** — screentone representation/synthesis for manga. Xie's hierarchical grid anchors relate to black-ink's grid-based dot spacing (`spacing = mix(3.8, 4.2, density)`). |

## Key Themes

1. **Layered edge hierarchy** — Decomposing edges into semantic layers (silhouette, structural, texture) for priority-driven compositing
2. **Procedural noise for mark-making** — Value noise, smudge, paper erosion for organic stroke appearance
3. **Screentone as tonal language** — Dot/hatch patterns as manga-specific shadow representation vs. continuous grayscale
4. **Post-processing NPR** — Image-space stylization without geometry buffers (framebuffer-only surrogate)

## Research Gaps

- Real-time screentone synthesis with learned density maps (Xie's approach is offline)
- Depth-aware edge hierarchy (AHEAD uses depth; black-ink currently uses luma-only proxy)
- Temporal coherence for animated manga rendering with stable screentone

## Collection Status

| Source | Coverage |
|--------|----------|
| Zotero NPR | 1 / 3 (Liu2025 in Zotero; Roshaan2026 + Xie2025 pending import) |
| Local Papers/ | 3 / 3 |
