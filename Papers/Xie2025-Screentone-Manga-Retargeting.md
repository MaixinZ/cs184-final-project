---
title: "Screentone-Preserved Manga Retargeting"
authors: [Minshan Xie, Menghan Xia, Chengze Li, Xueting Liu, Tien-Tsin Wong]
year: 2025
venue: "Computer Graphics Forum"
volume: 44
issue: 2
doi: "10.1111/cgf.70096"
url: "https://onlinelibrary.wiley.com/doi/full/10.1111/cgf.70096"
arxiv: "2203.03396"
zotero_key: 7X5J6WQF
keywords: [screentone, manga, retargeting, halftone, image resizing]
concepts: [screentone synthesis, manga processing, aliasing-free sampling, tone preservation]
methods: [hierarchical grid-based anchors, recurrent proposal selection, translation-invariant loss]
related_papers: [Liu2025-Pencil-Drawing-Simulation, Roshaan2026-AHEAD]
linked_knowledge: [Knowledge/Literature-Overview.md]
---

# Screentone-Preserved Manga Retargeting

## Claim

The first automatic manga retargeting method that preserves both prominent structure and fine screentone patterns during resolution changes.

## Research Question

How to resize manga images while maintaining the visual integrity of screentone patterns (dots, lines, cross-hatching) that are destroyed by standard interpolation?

## Method

- **Hierarchical grid-based anchors**: Multi-scale sampling strategy for aliasing-free screentone proposals
- **Recurrent Proposal Selection Module (RPSM)**: Adaptively integrates proposals for target screentone synthesis
- **Translation-invariant screentone loss**: Facilitates training convergence for periodic patterns
- **Two-stage pipeline**: Structure preservation + screentone synthesis

## Evidence

- Published in Computer Graphics Forum (Eurographics venue, 2025)
- First method to address screentone preservation during retargeting
- Demonstrates superior quality vs. standard resizing and prior manga-specific methods

## Strengths

- Deep understanding of screentone as a structured visual language (not just texture)
- Hierarchical grid anchors relate to procedural screentone grid spacing
- Addresses aliasing — a real problem for periodic dot/hatch patterns
- Strong venue (CGF/Eurographics)

## Limitation

- Offline neural method, not real-time
- Focused on 2D manga image processing, not 3D→2D rendering
- Does not generate screentone from 3D shading — only preserves existing screentone

## Direct Relevance to Repo

**Medium — domain and technique overlap.** Xie et al.'s understanding of screentone structure directly informs how black-ink's `evalDotTone` generates its patterns:

| Aspect | Xie 2025 | black-ink |
|---|---|---|
| Screentone source | Existing manga images | Procedurally generated from shadow classification |
| Grid structure | Hierarchical grid-based anchors | `spacing = mix(3.8, 4.2, density)` with rotated grid |
| Dot shape | Preserved from source | Clustered micro-dots with smudge + paper erosion |
| Aliasing handling | Translation-invariant loss | Implicit (low-res procedural avoids aliasing) |
| Hatching | Preserved from source | `evalHatchPattern` + `evalCrossHatchPattern` |

**Insight for black-ink**: Xie's work validates that screentone is a first-class visual element requiring dedicated handling — not just "shading as dots." The hierarchical grid-anchor concept could inspire multi-scale screentone in black-ink for different depth ranges or object types.

## Relation to Other Papers

- Extends prior work by same group (Xie et al. CVPR 2021 on manga restoration)
- Complementary to Roshaan2026's edge work — Xie handles tonal fill, AHEAD handles edge structure
- Liu2025's noise approach generates organic strokes; Xie2025's approach preserves structured periodic patterns — two ends of the NPR mark-making spectrum
