---
title: "Engine-Integrated Cel-Shading for Unreal Engine 5"
authors: [Gabriel Paes Landim de Lucena, Charles Madeira, Cesar Rennó-Costa, Alyson Souza]
year: 2025
venue: "SIGGRAPH Asia 2025 Posters"
doi: "10.1145/3757374.3771456"
url: "https://dl.acm.org/doi/10.1145/3757374.3771456"
zotero_key: NXR3R96E
keywords: [cel-shading, NPR, Unreal Engine 5, deferred rendering, real-time, smoothstep]
concepts: [engine-integrated NPR, cel band quantization, deferred shading pipeline modification]
methods: [shading model replacement, smoothstep band transitions, Clear-Coat override]
related_papers: [Chen2025-3D-Neural-Stylization-Survey, Roshaan2026-AHEAD]
linked_knowledge: [Knowledge/Literature-Overview.md]
---

# Engine-Integrated Cel-Shading for Unreal Engine 5

## Claim

Modifying UE5's source code to replace the native Clear-Coat shading model with a custom cel-shader overcomes the limitations of post-processing-only NPR, enabling full compatibility with ray tracing, multiple dynamic lights, and deferred features.

## Research Question

How to integrate cel-shading directly into a modern PBR engine's deferred pipeline without losing access to advanced rendering features like ray-traced reflections?

## Method

- **Three-stage integration**: (1) isolate lighting pipeline from pre-processing, (2) replace existing shading model with custom logic, (3) implement artist-driven cel lighting calculation
- **Smoothstep band transitions**: same mathematical primitive as celluloid's `evalCelBand`
- **Deferred pipeline integration**: cel logic runs inside the engine's shading pass, not as a screen-space post-process
- Supports multiple dynamic lights, specular highlights, and ray tracing natively

## Evidence

- Published at SIGGRAPH Asia 2025 Posters
- Demonstrates compatibility with UE5's full rendering feature set
- Comparison against post-processing alternatives shows improved quality

## Strengths

- Directly addresses the same problem celluloid faces: cel shading from within a rendering pipeline
- Smoothstep-based band transitions are the identical mathematical primitive used in celluloid
- Overcomes the limitations of post-processing NPR by accessing lighting data before compositing
- Real-time, engine-integrated approach

## Limitation

- Requires engine source code modification (not portable to arbitrary frameworks)
- Tied to UE5's specific architecture (Clear-Coat replacement)
- Poster format — limited technical depth compared to a full paper

## Direct Relevance to Repo

**High — direct architectural parallel.** Lucena et al.'s smoothstep cel bands map directly to celluloid's `Celluloid_EvalCelBand` and `Celluloid_EvalBandIndex`. Both quantize illumination into discrete regions with soft transitions. The key difference is WHERE the quantization happens:

| Aspect | Lucena 2025 | celluloid |
|---|---|---|
| Pipeline position | Inside deferred shading pass | Image-space post-processing |
| Lighting access | True per-light N·L from engine | Pseudo N·L from luma gradient |
| Band transition | smoothstep (artist-driven) | `smoothstep(threshold - softness, threshold + softness, signal)` |
| Multi-light | Native support for multiple dynamic lights | Single virtual light direction |
| Specular | Engine-native specular with cel threshold | Blinn-Phong with `SpecThreshold` gate |
| Outline | Not addressed (separate concern) | Luma gradient + chroma edge detection |

**Upgrade path**: If celluloid's environment ever provides true geometry/lighting data (see `memory/celluloid.md` §5), Lucena's three-stage integration approach provides a blueprint for moving cel logic from post-processing into the lighting pass.

## Relation to Other Papers

- Generalizes the approach that Shading Rig (Petikam 2021) explored for art-directable cel shading
- Complementary to AHEAD (Roshaan 2026) — Lucena handles cel diffuse/specular, AHEAD handles edge hierarchy
- Contrasts with Chen 2025's neural approaches — Lucena is procedural/shader-based, not learned
