/*
    Tabby Shaders - Weather: wet surfaces, puddles, raindrop ripples, rainbow
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Requires: common.glsl, sky.glsl (hash12), noise.glsl
*/

// Wet world only where it actually rains (not in deserts or snowy biomes)
float getWetness() {
    return wetness * getBiomeRain();
}

float getRainHere() {
    return rainStrength * getBiomeRain();
}

// Puddles on flat, open top faces (0..1). They grow with wetness and dry slowly.
float getPuddleMask(vec2 worldXZ, float wet) {
    float n = noiseSmooth(worldXZ * 0.08) * 0.7 + noiseSmooth(worldXZ * 0.31 + 20.0) * 0.3;
    float threshold = 1.0 - wet * (0.25 + 0.45 * PUDDLE_AMOUNT);
    return smoothstep(threshold, threshold + 0.08, n) * wet;
}

// Raindrop ripples: two offset grids, a ring spreads in every cell.
// Returns: gradient of the wave height in xz (for the normal)
vec2 getRainRipples(vec2 worldXZ) {
    vec2 grad = vec2(0.0);
    for (int layer = 0; layer < 2; layer++) {
        float fl = float(layer);
        vec2 p = worldXZ * (1.3 - fl * 0.4) + fl * vec2(17.3, 9.1);
        vec2 cell = floor(p);
        float rnd = hash12(cell + fl * 31.0);
        vec2 center = 0.25 + 0.5 * vec2(rnd, fract(rnd * 17.13));
        float t = fract(frameTimeCounter * 1.1 + rnd * 7.0); // age of the ring (0..1)

        vec2 d = fract(p) - center;
        float r = length(d);
        float x = r - t * 0.45;
        float envelope = (1.0 - t) * (1.0 - t) * (1.0 - smoothstep(0.0, 0.12, abs(x)));
        grad += d / max(r, 1e-3) * (cos(x * 45.0) * envelope);
    }
    return grad * 0.25;
}

// t: 0 = violet (inside), 1 = red (outside)
vec3 rainbowSpectrum(float t) {
    float hue = (1.0 - t) * 0.75;
    return clamp(abs(fract(hue + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// Rainbow after rain, opposite the sun (primary bow ~42 degrees, secondary bow ~51 degrees)
vec3 getRainbow(vec3 viewDir, vec3 sunVec, vec3 upVec) {
    float amount = smoothstep(0.15, 0.6, getWetness()) * (1.0 - smoothstep(0.02, 0.3, rainStrength)) * sunVisibility;
    if (amount < 0.001) return vec3(0.0);

    float angle = degrees(acos(clamp(dot(viewDir, -sunVec), -1.0, 1.0)));
    vec3 bow = vec3(0.0);

    float t1 = (angle - 40.0) / 2.5;
    if (t1 > 0.0 && t1 < 1.0) bow += rainbowSpectrum(t1) * sin(t1 * 3.14159);

    float t2 = (angle - 50.5) / 3.0;
    if (t2 > 0.0 && t2 < 1.0) bow += rainbowSpectrum(1.0 - t2) * (sin(t2 * 3.14159) * 0.35);

    float horizon = smoothstep(-0.02, 0.08, dot(viewDir, upVec));
    return bow * (amount * horizon * 0.35);
}
