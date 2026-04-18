#ifndef SPLIT_STACK_EFFECTS_NEW_FXH
#define SPLIT_STACK_EFFECTS_NEW_FXH

#include "AppendShared/oilPaint_append_shared.fxh"
#include "AppendShared/painter_append_shared.fxh"
#include "AppendShared/celluloid_append_shared.fxh"
#include "AppendShared/black-ink_append_shared.fxh"
#include "AppendShared/pixelArt_append_shared.fxh"
#include "AppendShared/MyopiaDepthBlur_append_shared.fxh"
#include "AppendShared/HyperopiaDepthBlur_append_shared.fxh"
#include "AppendShared/DepthCoordinateProbe_append_shared.fxh"
#include "AppendShared/slider_append_shared.fxh"
#include "AppendShared/DepthFogStylization_append_shared.fxh"
#include "AppendShared/DepthLayeredPainterly_append_shared.fxh"
#include "AppendShared/DepthOutlineOverlay_append_shared.fxh"
#include "AppendShared/DepthScreentoneOverlay_append_shared.fxh"

#define SSC_EFFECT_NONE 0
#define SSC_EFFECT_OIL_PAINT 1
#define SSC_EFFECT_PAINTER 2
#define SSC_EFFECT_CELLULOID 3
#define SSC_EFFECT_BLACK_INK 4
#define SSC_EFFECT_PIXEL_ART 5
#define SSC_EFFECT_MYOPIA 6
#define SSC_EFFECT_HYPEROPIA 7
#define SSC_EFFECT_DEPTH_PROBE 8
#define SSC_EFFECT_RG_ASSIST 9
#define SSC_EFFECT_DEPTH_FOG 10
#define SSC_EFFECT_DEPTH_LAYERED_PAINTERLY 11
#define SSC_EFFECT_DEPTH_OUTLINE 12
#define SSC_EFFECT_DEPTH_SCREENTONE 13

float3 SSB_ApplyEffect(sampler source_sampler, float2 uv, int effect_id)
{
    if (effect_id == SSC_EFFECT_OIL_PAINT)
        return OilPaintAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PAINTER)
        return PainterAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_CELLULOID)
        return CelluloidAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_BLACK_INK)
        return BlackInkAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_PIXEL_ART)
        return PixelArtAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_MYOPIA)
        return MyopiaAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_HYPEROPIA)
        return HyperopiaAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_PROBE)
        return DepthProbeAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_RG_ASSIST)
        return SliderAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_FOG)
        return DFSAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_LAYERED_PAINTERLY)
        return DLPAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_OUTLINE)
        return DOOAppend_ApplyFromSampler(source_sampler, uv);
    if (effect_id == SSC_EFFECT_DEPTH_SCREENTONE)
        return DSOAppend_ApplyFromSampler(source_sampler, uv);

    return tex2D(source_sampler, saturate(uv)).rgb;
}

#endif
