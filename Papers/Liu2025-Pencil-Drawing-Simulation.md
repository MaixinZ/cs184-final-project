---
title: "Pencil drawing simulation based on improved hybrid noise"
authors: [Liu Siyi, Liu Yibiao, Sheng Yun]
year: 2025
venue: "Signal, Image and Video Processing"
volume: 19
issue: 15
pages: 1283
doi: "10.1007/s11760-025-04857-3"
url: "https://link.springer.com/10.1007/s11760-025-04857-3"
zotero_key: RFNSMVVZ
keywords: [pencil drawing, NPR, hybrid noise, simulation]
concepts: [non-photorealistic rendering, noise-based stroke generation]
methods: [improved hybrid noise]
related_papers: [Roshaan2026-AHEAD, Xie2025-Screentone-Manga-Retargeting]
linked_knowledge: [Knowledge/Literature-Overview.md]
---

# Pencil Drawing Simulation Based on Improved Hybrid Noise

## Claim

Proposes an improved hybrid noise method for simulating pencil drawing effects with more natural stroke textures.

## Research Question

How to generate realistic pencil drawing effects using improved noise-based approaches?

## Method

- Improved hybrid noise algorithm for stroke texture generation
- Combines multiple noise functions for natural pencil appearance

## Evidence

- Published in Signal, Image and Video Processing (2025)
- Full text not yet extracted (no PDF attachment in Zotero)

## Strengths

- Directly relevant to NPR pencil/sketch rendering
- Recent work (2025) with up-to-date techniques

## Limitation

- Full text not available for detailed analysis yet

## Direct Relevance to Repo

**Medium — technique overlap.** The hybrid noise approach parallels black-ink's `valueNoise`-based procedural texture generation used in `evalDotTone`, `evalPaperGrain`, and `evalDirectionalSmudge`. Both use multi-octave noise composition for organic mark-making:

| Aspect | Liu 2025 | black-ink |
|---|---|---|
| Noise type | Improved hybrid noise | Value noise (hash-based) |
| Application | Pencil stroke simulation | Micro-dot clustering + paper grain + smudge |
| Composition | Multi-scale noise blending | `coarse*0.50 + mid*0.34 + fine*0.16` |
| Rendering | Offline | Real-time shader |

## Relation to Other Papers

- Noise-based stroke generation complements Roshaan2026's edge detection (organic marks vs. structural lines)
- Contrasts with Xie2025's structured periodic screentone — Liu generates organic noise, Xie preserves regular patterns
