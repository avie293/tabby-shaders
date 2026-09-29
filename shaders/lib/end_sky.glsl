/*
    Tabby Shaders - End sky with storms
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Dark void with a violet horizon, surrounded by a rotating storm band with lightning,
    a slowly turning vortex at the zenith. Minecraft's end flashes light everything up.
    Requires: common.glsl, sky.glsl, noise.glsl
*/

const vec3 END_STORM_DARK   = vec3(0.020, 0.008, 0.040);
const vec3 END_STORM_BRIGHT = vec3(0.420, 0.160, 0.680);

vec3 rotateY(vec3 d, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec3(d.x * c - d.z * s, d.y, d.x * s + d.z * c);
}

// Density of the storm clouds in a sky direction (0..1)
float endStormDensity(vec3 dir, float t) {
    // The storm rotates around the vertical axis
    vec3 p = rotateY(dir, t * 0.02) * 6.0;

    // Domain warping -> turbulent, twisted shapes
    vec3 warp = vec3(noise3D(p + vec3(0.0, t * 0.05, 0.0)),
                     noise3D(p + vec3(5.2, 1.3, t * 0.04)),
                     noise3D(p + vec3(2.1, 7.7, 3.3))) - 0.5;
    p += warp * 1.8;

    float n = noise3D(p) * 0.55 + noise3D(p * 2.1 + 11.0) * 0.28 + noise3D(p * 4.3 + 23.0) * 0.17;

    // Dense band around the horizon, thin veils above
    float band = exp(-dir.y * dir.y * 6.0) * 0.8 + 0.15;
    return smoothstep(0.42, 0.85, n) * band; // gaps let the void and stars through
}

// Spiral vortex at the zenith
float endVortex(vec3 dir, float t) {
    if (dir.y < 0.2) return 0.0;
    float r = length(dir.xz) / dir.y;
    float angle = atan(dir.z, dir.x);
    float spiral = sin(angle * 3.0 + log(r + 0.05) * 4.0 - t * 0.15) * 0.5 + 0.5;
    float fade = smoothstep(0.2, 0.6, dir.y) * smoothstep(0.02, 0.25, r) * (1.0 - smoothstep(0.8, 2.5, r));
    return spiral * spiral * fade;
}

// Lightning in the storm: bright spots where a bolt currently strikes
vec3 endLightning(vec3 dir, float storm) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        vec3 boltDir;
        float intensity = getEndBolt(i, boltDir);
        if (intensity > 0.001) {
            float d = 1.0 - dot(dir, boltDir);
            col += END_FLASH_COL * (intensity * exp(-d * 18.0) * (0.3 + storm));
        }
    }
    return col;
}

vec3 getEndSky(vec3 worldDir, float pxAngle) {
    float t = frameTimeCounter;
    vec3 col = getEndSkyBase(worldDir);

    #ifdef END_STORMS
    float storm = endStormDensity(worldDir, t);
    #else
    float storm = 0.0;
    #endif

    // Stars (covered by the storm)
    #ifdef SHADER_STARS
    col += getStars(worldDir, pxAngle) * ((1.0 - storm) * 0.6 * STAR_BRIGHTNESS);
    #endif

    #ifdef END_STORMS
    vec3 lightning = endLightning(worldDir, storm);
    float flash = getEndSkyFlash();

    // Storm clouds: dark with bright rims, lit by lightning
    vec3 stormCol = mix(END_STORM_DARK, END_STORM_BRIGHT, storm * storm)
                  + lightning * 1.5 + END_FLASH_COL * (flash * 0.8);
    col = mix(col, stormCol, storm * 0.85);
    col += lightning * 0.3; // glow of the lightning next to the clouds too

    // Vortex at the zenith
    float vortex = endVortex(worldDir, t);
    col += (vec3(0.25, 0.08, 0.40) + END_FLASH_COL * flash) * (vortex * 0.6);
    #endif

    return col * SKY_BRIGHTNESS;
}
