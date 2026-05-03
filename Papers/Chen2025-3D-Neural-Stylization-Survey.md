---
title: "Advances in 3D Neural Stylization: A Survey"
authors: [Yingshu Chen, Guocheng Shao, Ka Chun Shum, Binh-Son Hua, Sai-Kit Yeung]
year: 2025
venue: "International Journal of Computer Vision"
volume: 133
issue: 8
doi: "10.1007/s11263-025-02403-9"
url: "https://link.springer.com/article/10.1007/s11263-025-02403-9"
arxiv: "2311.18328"
zotero_key: NGBIHNA8
keywords: [neural stylization, NPR, survey, 3D rendering, style transfer]
concepts: [neural stylization taxonomy, scene representation, guidance data, optimization strategies]
methods: [mesh stylization, point cloud stylization, volumetric stylization, implicit field stylization]
related_papers: [Lucena2025-UE5-Cel-Shading, Roshaan2026-AHEAD]
linked_knowledge: [Knowledge/Literature-Overview.md]
---

# Advances in 3D Neural Stylization: A Survey

## Claim

Establishes a comprehensive taxonomy for neural 3D stylization methods, covering scene representations (meshes, point clouds, volumes, implicit fields), guidance data types, optimization strategies, and output styles.

## Research Question

How do recent neural network methods create and manipulate stylized 3D assets, and what is the landscape of approaches across representation types?

## Method

- **Taxonomy**: Organizes methods by scene representation × guidance data × optimization strategy × output style
- **Coverage**: Meshes, point clouds, volumetric simulation, implicit fields (NeRF, 3DGS)
- **2D background**: Reviews foundational 2D stylization that underpins 3D methods
- Curated paper list maintained on GitHub

## Evidence

- Published in International Journal of Computer Vision (IJCV 2025, Vol. 133, Issue 8)
- Comprehensive coverage of recent methods through 2024

## Strengths

- Provides landscape context for where procedural NPR (like celluloid) sits relative to neural approaches
- Covers both classical NPR roots and modern neural methods
- Strong venue (IJCV)

## Limitation

- Neural-focused — does not deeply analyze classical procedural NPR (cel shading, toon shading)
- Does not cover post-processing image-space NPR in detail
- Survey breadth means individual techniques get limited depth

## Direct Relevance to Repo

**Low-Medium — contextual survey.** Positions the celluloid shader within the broader NPR landscape. celluloid is a classical procedural approach; this survey shows what neural alternatives exist and where they excel or fall short compared to real-time procedural methods.

| Aspect | Chen 2025 Survey | celluloid |
|---|---|---|
| Approach family | Neural (learned) | Procedural (hand-authored) |
| Rendering speed | Typically offline or slow inference | Real-time (single pass) |
| Art control | Training data / reference images | Direct parameter tuning |
| 3D representation | NeRF, 3DGS, mesh, etc. | Framebuffer-only (no 3D access) |

**Insight for celluloid**: The survey highlights that neural methods still struggle with real-time performance and fine-grained artistic control — the exact areas where procedural cel shading like celluloid excels. However, neural methods achieve broader style diversity that procedural approaches cannot match.

## Relation to Other Papers

- Provides broad context for all NPR papers in this project
- Lucena 2025's engine-integrated approach represents the procedural counterpoint to the neural methods surveyed
- AHEAD (Roshaan 2026) bridges both worlds — classical edge detection hierarchy in a modern framework
