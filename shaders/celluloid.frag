#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform sampler2D tex;
uniform int uDebugMode;
uniform int uShadeEnabled;

uniform vec3 uLightDir;
uniform vec3 uLightTint;
uniform vec3 uMidTint;
uniform vec3 uShadowTint;
uniform vec3 uSpecColor;
uniform vec3 uRimColor;
uniform vec3 uOutlineColor;
uniform vec3 uAtmosphereColor;

uniform float uShadowThreshold;
uniform float uShadowSoftness;
uniform float uMidThreshold;
uniform float uHighlightThreshold;
uniform float uSpecThreshold;
uniform float uRimThreshold;
uniform float uOutlineThreshold;
uniform float uFogWeight;

float luminance(vec3 color)
{
    return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 sampleRegionAverage(vec2 sampleUv, vec2 texel)
{
    vec3 color = vec3(0.0);
    color += texture(tex, sampleUv).rgb * 4.0;
    color += texture(tex, sampleUv + vec2(texel.x, 0.0)).rgb;
    color += texture(tex, sampleUv - vec2(texel.x, 0.0)).rgb;
    color += texture(tex, sampleUv + vec2(0.0, texel.y)).rgb;
    color += texture(tex, sampleUv - vec2(0.0, texel.y)).rgb;
    color += texture(tex, sampleUv + texel).rgb;
    color += texture(tex, sampleUv - texel).rgb;
    color += texture(tex, sampleUv + vec2(texel.x, -texel.y)).rgb;
    color += texture(tex, sampleUv + vec2(-texel.x, texel.y)).rgb;
    return color / 12.0;
}

vec2 evalLumaGradient(vec2 sampleUv, vec2 texel)
{
    float lL = luminance(sampleRegionAverage(sampleUv - vec2(texel.x, 0.0), texel));
    float lR = luminance(sampleRegionAverage(sampleUv + vec2(texel.x, 0.0), texel));
    float lU = luminance(sampleRegionAverage(sampleUv + vec2(0.0, texel.y), texel));
    float lD = luminance(sampleRegionAverage(sampleUv - vec2(0.0, texel.y), texel));
    return vec2(lR - lL, lU - lD);
}

vec3 evalPseudoNormal(vec2 lumaGradient)
{
    return normalize(vec3(-lumaGradient * 3.2, 1.0));
}

float evalCelBand(float signalValue, float threshold, float softness)
{
    return smoothstep(threshold - softness, threshold + softness, signalValue);
}

float evalBandIndex(float shadeSignal)
{
    float bandIndex = 0.0;
    bandIndex += evalCelBand(shadeSignal, uShadowThreshold, uShadowSoftness);
    bandIndex += evalCelBand(shadeSignal, uMidThreshold, uShadowSoftness);
    bandIndex += evalCelBand(shadeSignal, uHighlightThreshold, uShadowSoftness * 0.75);
    return bandIndex;
}

vec3 evalCelDiffuse(vec3 baseColor, float shadeSignal)
{
    float shadowToMid = evalCelBand(shadeSignal, uShadowThreshold, uShadowSoftness);
    float midToLight = evalCelBand(shadeSignal, uMidThreshold, uShadowSoftness);
    float lightToHighlight = evalCelBand(shadeSignal, uHighlightThreshold, uShadowSoftness * 0.75);

    vec3 shadowRegion = baseColor * uShadowTint;
    vec3 midRegion = baseColor * uMidTint;
    vec3 lightRegion = baseColor * uLightTint;
    vec3 highlightRegion = mix(lightRegion, vec3(1.0), 0.22);

    vec3 diffuse = mix(shadowRegion, midRegion, shadowToMid);
    diffuse = mix(diffuse, lightRegion, midToLight);
    diffuse = mix(diffuse, highlightRegion, lightToHighlight * 0.65);
    return diffuse;
}

float evalStylizedShadow(float shadeSignal, float cavityMask)
{
    float broadShadow = 1.0 - evalCelBand(shadeSignal, uShadowThreshold, uShadowSoftness);
    return clamp(max(broadShadow * 0.88, cavityMask * 0.55), 0.0, 1.0);
}

vec3 evalAmbientHemisphere(vec3 normalValue, vec3 baseColor, float aoMask)
{
    vec3 skyColor = vec3(0.53, 0.67, 0.84);
    vec3 groundColor = vec3(0.40, 0.34, 0.28);
    float hemiMix = normalValue.y * 0.5 + 0.5;
    vec3 hemiColor = mix(groundColor, skyColor, hemiMix);
    float ambientStrength = mix(0.58, 0.34, aoMask);
    return baseColor * hemiColor * ambientStrength;
}

float evalSpecularMask(vec3 normalValue, vec3 lightDirValue, vec3 viewDirValue, float shadeSignal, float materialMask)
{
    vec3 halfVector = normalize(lightDirValue + viewDirValue);
    float ndh = max(dot(normalValue, halfVector), 0.0);
    float specSignal = pow(ndh, 18.0);
    float specMask = smoothstep(uSpecThreshold - 0.08, uSpecThreshold + 0.08, specSignal);
    specMask *= smoothstep(0.50, 0.85, shadeSignal);
    specMask *= materialMask;
    return specMask;
}

vec3 evalStylizedSpecular(vec3 normalValue, vec3 lightDirValue, vec3 viewDirValue, float shadeSignal, float materialMask)
{
    return uSpecColor * evalSpecularMask(normalValue, lightDirValue, viewDirValue, shadeSignal, materialMask) * 0.48;
}

float evalRimMask(vec3 normalValue, vec3 viewDirValue, float edgeMask, float shadowMask)
{
    float rim = 1.0 - max(dot(normalValue, viewDirValue), 0.0);
    rim = pow(rim, 1.35);
    rim = smoothstep(uRimThreshold, 1.0, rim);
    rim *= mix(0.45, 1.0, shadowMask);
    rim *= mix(0.35, 0.85, edgeMask);
    return rim;
}

vec3 evalRimLight(vec3 normalValue, vec3 viewDirValue, float edgeMask, float shadowMask)
{
    return uRimColor * evalRimMask(normalValue, viewDirValue, edgeMask, shadowMask) * 0.42;
}

float evalOutlineFromDepthNormal(vec2 lumaGradient, vec3 baseColor, vec3 smoothColor)
{
    float lumaEdge = length(lumaGradient);
    float chromaEdge = length(baseColor - smoothColor);
    float edgeSignal = lumaEdge * 2.2 + chromaEdge * 1.35;
    return smoothstep(uOutlineThreshold, uOutlineThreshold + 0.12, edgeSignal);
}

float evalFogFactor(float detailMask, vec2 sampleUv)
{
    float farProxy = smoothstep(0.18, 0.82, 1.0 - detailMask);
    float skyBias = smoothstep(0.20, 0.92, sampleUv.y);
    return clamp((farProxy * 0.78 + skyBias * 0.22) * uFogWeight, 0.0, 1.0);
}

vec3 applyAtmosphericPerspective(vec3 colorValue, float fogFactor)
{
    vec3 foggedColor = mix(colorValue, uAtmosphereColor, fogFactor * 0.38);
    float foggedLuma = luminance(foggedColor);
    vec3 flattenedColor = mix(foggedColor, mix(vec3(foggedLuma), uAtmosphereColor, 0.35), fogFactor * 0.30);
    return mix(colorValue, flattenedColor, fogFactor);
}

vec3 applyBandPreservingTonemap(vec3 colorValue)
{
    float peak = max(max(colorValue.r, colorValue.g), colorValue.b);
    float shoulder = max(peak - 1.0, 0.0);
    colorValue /= 1.0 + shoulder * 0.65;
    colorValue = pow(max(colorValue, 0.0), vec3(0.96));
    return clamp(colorValue, 0.0, 1.0);
}

vec3 bandDebugColor(float bandIndex)
{
    if (bandIndex < 0.5) {
        return vec3(0.16, 0.23, 0.44);
    }
    if (bandIndex < 1.5) {
        return vec3(0.39, 0.53, 0.82);
    }
    if (bandIndex < 2.5) {
        return vec3(0.85, 0.72, 0.39);
    }
    return vec3(0.98, 0.93, 0.76);
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));

    vec3 baseColor = texture(tex, uv).rgb;
    if (uShadeEnabled == 0) {
        FragColor = vec4(baseColor, 1.0);
        return;
    }

    vec3 smoothColor = sampleRegionAverage(uv, texel);
    float smoothLuma = luminance(smoothColor);
    vec2 lumaGradient = evalLumaGradient(uv, texel);
    vec3 pseudoNormal = evalPseudoNormal(lumaGradient);

    vec3 lightDirValue = normalize(uLightDir);
    vec3 viewDirValue = vec3(0.0, 0.0, 1.0);

    float ndotl = max(dot(pseudoNormal, lightDirValue), 0.0);
    float detailMask = clamp(length(baseColor - smoothColor) * 1.8 + length(lumaGradient) * 2.4, 0.0, 1.0);
    float cavityMask = smoothstep(0.18, 0.65, detailMask) * (1.0 - smoothstep(0.58, 0.92, smoothLuma));
    float shadeSignal = clamp(mix(smoothLuma, ndotl, 0.62) + 0.10, 0.0, 1.0);
    float bandIndex = evalBandIndex(shadeSignal);

    vec3 celDiffuse = evalCelDiffuse(smoothColor, shadeSignal);
    float shadowMask = evalStylizedShadow(shadeSignal, cavityMask);
    vec3 ambientTerm = evalAmbientHemisphere(pseudoNormal, smoothColor, cavityMask);
    float specMask = smoothstep(0.24, 0.82, smoothLuma) * (1.0 - detailMask * 0.30);
    vec3 specularTerm = evalStylizedSpecular(pseudoNormal, lightDirValue, viewDirValue, shadeSignal, specMask);
    float outlineMask = evalOutlineFromDepthNormal(lumaGradient, baseColor, smoothColor);
    float rimMask = evalRimMask(pseudoNormal, viewDirValue, outlineMask, shadowMask);
    vec3 rimTerm = uRimColor * rimMask * 0.42;
    float fogFactor = evalFogFactor(detailMask, uv);

    vec3 litColor = celDiffuse + ambientTerm + specularTerm + rimTerm;
    litColor = mix(litColor, baseColor, 0.18);

    vec3 localOutlineColor = mix(baseColor * 0.28, uOutlineColor, 0.75);
    float outlineBlend = outlineMask * (1.0 - fogFactor * 0.65);
    litColor = mix(litColor, localOutlineColor, outlineBlend * 0.88);
    litColor = applyAtmosphericPerspective(litColor, fogFactor);
    litColor = applyBandPreservingTonemap(litColor);

    if (uDebugMode == 1) {
        FragColor = vec4(vec3(ndotl), 1.0);
        return;
    }
    if (uDebugMode == 2) {
        FragColor = vec4(bandDebugColor(bandIndex), 1.0);
        return;
    }
    if (uDebugMode == 3) {
        FragColor = vec4(vec3(shadowMask), 1.0);
        return;
    }
    if (uDebugMode == 4) {
        FragColor = vec4(vec3(rimMask), 1.0);
        return;
    }
    if (uDebugMode == 5) {
        FragColor = vec4(vec3(outlineMask), 1.0);
        return;
    }
    if (uDebugMode == 6) {
        FragColor = vec4(vec3(fogFactor), 1.0);
        return;
    }

    FragColor = vec4(litColor, 1.0);
}
