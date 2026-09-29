/*
    Tabby Shaders - Waving plants and leaves (vertex shader only, very cheap)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    IDs from block.properties:
        10001 = small plants (only the top vertices move)
        10002 = upper half of tall plants (everything moves)
        10003 = leaves
*/

vec3 getWind(vec3 worldPos) {
    float t = frameTimeCounter * WAVING_SPEED;
    vec3 w;
    w.x = sin(t * 1.4 + worldPos.x * 0.6 + worldPos.z * 0.3) * 0.6 + sin(t * 2.3 + worldPos.z * 0.9) * 0.3;
    w.z = sin(t * 1.1 + worldPos.z * 0.7 + worldPos.x * 0.2) * 0.6 + cos(t * 2.7 + worldPos.x * 0.8) * 0.3;
    w.y = sin(t * 1.7 + worldPos.x * 0.5 + worldPos.z * 0.5) * 0.15;
    return w * (0.07 * (1.0 + rainStrength * 1.5));
}

vec3 getWavingOffset(vec3 worldPos, int id, bool isTop, float skyLight) {
    float strength = 0.0;

    #ifdef WAVING_PLANTS
    if (id == 10001 && isTop) strength = 1.0;
    if (id == 10002) strength = isTop ? 2.0 : 1.0;
    #endif

    #ifdef WAVING_LEAVES
    if (id == 10003) strength = 0.5;
    #endif

    if (strength == 0.0) return vec3(0.0);

    // No wind in caves
    return getWind(worldPos) * (strength * skyLight * skyLight);
}
