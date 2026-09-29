/*
    Tabby Shaders - Noise from noisetex
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    noisetex = 256x256 random values from Iris, smoothly filtered and tileable.
    Coordinates in texels (1 texel = 1 random value) -> one texture fetch per octave.
*/

uniform sampler2D noisetex;

vec4 noiseLinear(vec2 texel) {
    return texture2D(noisetex, texel / 256.0);
}

// Smooth 2D noise without diamond artifacts
float noiseSmooth(vec2 texel) {
    vec2 i = floor(texel);
    vec2 f = fract(texel);
    f = f * f * (3.0 - 2.0 * f);
    return texture2D(noisetex, (i + f + 0.5) / 256.0).r;
}

// Smooth 3D noise: two 2D slices blended along y
float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    vec2 uv = i.xz + f.xz + 0.5;
    float a = texture2D(noisetex, (uv + i.y * vec2(37.0, 17.0)) / 256.0).g;
    float b = texture2D(noisetex, (uv + (i.y + 1.0) * vec2(37.0, 17.0)) / 256.0).g;
    return mix(a, b, f.y);
}
