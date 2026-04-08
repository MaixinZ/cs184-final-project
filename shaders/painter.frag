#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform sampler2D tex;
uniform int uShadeEnabled;

float luminance(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 sampleBlur(sampler2D source, vec2 sampleUv, vec2 texel)
{
    vec3 blur = vec3(0.0);
    blur += texture(source, sampleUv).rgb * 4.0;
    blur += texture(source, sampleUv + vec2(texel.x, 0.0)).rgb;
    blur += texture(source, sampleUv - vec2(texel.x, 0.0)).rgb;
    blur += texture(source, sampleUv + vec2(0.0, texel.y)).rgb;
    blur += texture(source, sampleUv - vec2(0.0, texel.y)).rgb;
    blur += texture(source, sampleUv + texel).rgb;
    blur += texture(source, sampleUv - texel).rgb;
    blur += texture(source, sampleUv + vec2(texel.x, -texel.y)).rgb;
    blur += texture(source, sampleUv + vec2(-texel.x, texel.y)).rgb;
    return blur / 12.0;
}

vec3 applyPainterTone(vec3 color, vec3 blur)
{
    vec3 painter = mix(color, blur, 0.55);

    float luma = luminance(painter);
    painter = mix(vec3(luma), painter, 0.88);

    painter.r *= 1.10;
    painter.g *= 1.00;
    painter.b *= 0.97;

    painter = pow(painter, vec3(0.92));

    float levels = 6.0;
    return floor(painter * levels) / levels;
}

float computeEdge(sampler2D source, vec2 sampleUv, vec2 texel)
{
    float lL = luminance(texture(source, sampleUv - vec2(texel.x, 0.0)).rgb);
    float lR = luminance(texture(source, sampleUv + vec2(texel.x, 0.0)).rgb);
    float lU = luminance(texture(source, sampleUv + vec2(0.0, texel.y)).rgb);
    float lD = luminance(texture(source, sampleUv - vec2(0.0, texel.y)).rgb);

    float dx = lR - lL;
    float dy = lU - lD;
    return length(vec2(dx, dy));
}

float paperGrain(vec2 sampleUv)
{
    return fract(sin(dot(sampleUv * vec2(1400.0, 900.0), vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 compositePaper(vec3 painter, float edge, float grain)
{
    vec3 paper = vec3(0.95, 0.88, 0.74);
    vec3 result = mix(paper, painter, 0.92);

    vec3 lineColor = vec3(0.42, 0.28, 0.10);
    float lineMask = smoothstep(0.05, 0.16, edge);
    result = mix(result, lineColor, lineMask * 0.55);

    vec3 gold = vec3(0.82, 0.68, 0.30);
    float goldMask = smoothstep(0.10, 0.22, edge) * 0.35;
    result = mix(result, gold, goldMask);

    return result * (0.985 + 0.03 * grain);
}

void main()
{
    vec2 texel = 1.0 / vec2(textureSize(tex, 0));
    vec3 baseColor = texture(tex, uv).rgb;
    if (uShadeEnabled == 0) {
        FragColor = vec4(baseColor, 1.0);
        return;
    }
    vec3 blur = sampleBlur(tex, uv, texel);
    vec3 painter = applyPainterTone(baseColor, blur);
    float edge = computeEdge(tex, uv, texel);
    float grain = paperGrain(uv);
    vec3 result = compositePaper(painter, edge, grain);

    FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
