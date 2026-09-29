/*
    Tabby Shaders - Lighting
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Warm torch light, bluish moon light, sky light from the lightmap.
*/

// blockCol = color of the torch light (default or from colored lighting)
vec3 getBlockLight(float bl, vec3 blockCol) {
    float b2 = bl * bl;
    return blockCol * (b2 * b2 * 1.6 + bl * 0.06) * BLOCKLIGHT_BRIGHTNESS;
}

// lm.x = block light, lm.y = sky light (0..1)
// directAmount = NdotL * shadow, upDot = normal * up (-1..1)
vec3 getLighting(vec2 lm, float directAmount, float upDot, vec3 lightCol, vec3 ambientCol, vec3 blockCol) {
    #ifdef OVERWORLD
    float skyAmb = lm.y * lm.y;
    #else
    float skyAmb = 1.0;
    #endif

    // Top faces a bit brighter than sides/bottoms (replaces vanilla face shading)
    float dirAmb = 0.8 + 0.2 * upDot;

    vec3 ambient  = ambientCol * (skyAmb * dirAmb);
    vec3 direct   = lightCol * directAmount;
    vec3 block    = getBlockLight(lm.x, blockCol);
    vec3 minLight = vec3(0.85, 0.90, 1.00) * (MIN_LIGHT * 0.015) + nightVision * 0.35;

    return ambient + direct + block + minLight;
}
