---
title: "AHEAD: Adaptive Hierarchical Edge Detection for Real-Time Artistic Stylization"
authors: [M K Lino Roshaan]
year: 2026
venue: "Research Square (preprint)"
doi: "10.5281/zenodo.18765546"
url: "https://www.researchsquare.com/article/rs-8849147/v1"
zotero_key: RJI35I8Z
keywords: [edge detection, NPR, real-time, post-processing, silhouette, game engine]
concepts: [hierarchical edge detection, adaptive sensitivity, post-processing NPR]
methods: [three-layer hierarchy, max-pooling fusion, Sobel/Laplacian edge kernels]
related_papers: [Liu2025-Pencil-Drawing-Simulation, Xie2025-Screentone-Manga-Retargeting]
linked_knowledge: [Knowledge/Literature-Overview.md]
github: "https://github.com/Chronos-Asteri/AHEAD-AdaptiveEdgeDetection"
---

# AHEAD: Adaptive Hierarchical Edge Detection for Real-Time Artistic Stylization

## Claim

A unified, real-time post-processing shader architecture using adaptive sensitivity and a three-layer hierarchy overcomes limitations in traditional single-pass edge detection for NPR stylization.

## Research Question

How to decompose scene edges into semantically meaningful layers (silhouette, structure, texture) for controllable, high-fidelity artistic stylization in real-time?

## Method

- **Three-layer hierarchy**: Silhouette (object boundaries), Structure (geometric features), Texture (surface detail)
- **Adaptive sensitivity**: Per-layer threshold tuning based on scene content
- **Max-pooling fusion**: Integrates edge layers while preserving integrity, better than linear averaging
- **Post-processing shader**: Operates on rendered framebuffer (color + depth + normals where available)
- Implemented across multiple game engines

## Evidence

- Significant reduction in manual tuning vs. single-pass approaches
- High-fidelity artistic stylization with minimal performance overhead
- Open-source implementation on GitHub

## Strengths

- Directly addresses the same problem as black-ink: post-processing edge decomposition
- Three-layer hierarchy is a principled generalization of black-ink's silhouette/crease/contact split
- Real-time performance validated in game engines
- Open-source, reproducible

## Limitation

- Preprint (not yet peer-reviewed in a major venue)
- Focuses on edge detection only; does not address tonal rendering (screentone, hatching, black fill)
- Uses depth/normal buffers when available — black-ink operates without these

## Direct Relevance to Repo

**High — direct architectural parallel.** AHEAD's Silhouette/Structure/Texture decomposition maps closely to black-ink's `evalViewSilhouette`/`evalCreaseLine`/`evalContactEdge` pipeline. Key differences:

| Aspect | AHEAD | black-ink |
|---|---|---|
| Edge input | Depth + normals + color | Luma gradient + alpha only |
| Fusion | Max-pooling | Priority-weighted compositing (`evalLinePriority`) |
| Tonal output | Edge lines only | Full ink pipeline (fill + tone + lines + paper) |
| Adaptivity | Per-layer adaptive thresholds | Fixed `OutlineThreshold` gates all layers |

**Upgrade path**: If black-ink gains access to depth buffers (see `memory/black-ink.md` §5), AHEAD's adaptive per-layer sensitivity could replace the current fixed `OutlineThreshold` for better silhouette/crease separation.

## Relation to Other Papers

- Generalizes classical Sobel/Canny edge detection into a hierarchical NPR framework
- Complementary to Xie2025's screentone work — AHEAD handles edges, Xie handles tonal fill
- Could be combined with Liu2025's noise techniques for edge-aware stroke rendering
