/*
    Tabby Shaders - BSL-style shader water
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    gbuffers_water: water color, depth, wave normal -> writes data to colortex2
    composite:      refraction, reflections (SSR + sky), sun glint
    Requires: common.glsl, sky.glsl (hash12)
*/

// ---------------------------------------------------------------------
//  Data in colortex2 (RGBA16): RG = normal (octahedral), B = mask + sky light + shadow
// ---------------------------------------------------------------------
vec2 encodeNormal(vec3 n) {
    n /= abs(n.x) + abs(n.y) + abs(n.z);
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

// 0 = no water, otherwise sky light and shadow (each 0..1) in one 16-bit channel
float packWaterInfo(float skyLight, float shadow) {
    float code = 1.0 + floor(skyLight * 250.0 + 0.5) * 251.0 + floor(shadow * 250.0 + 0.5);
    return code / 65535.0;
}

// x = is water (0/1), y = sky light, z = shadow
vec3 unpackWaterInfo(float b) {
    float code = floor(b * 65535.0 + 0.5) - 1.0;
    if (code < 0.0) return vec3(0.0);
    float sky = floor(code / 251.0);
    return vec3(1.0, sky / 250.0, (code - sky * 251.0) / 250.0);
}

#ifdef WATER_PROGRAM
// ---------------------------------------------------------------------
//  Waves: soft, round waves from noise (analytic derivative, 4 octaves)
// ---------------------------------------------------------------------
uniform sampler2D depthtex1; // depth without translucent blocks (sea floor)

vec3 noiseD(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u  = f * f * (3.0 - 2.0 * f);
    vec2 du = 6.0 * f * (1.0 - f);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;

    return vec3(a + k1 * u.x + k2 * u.y + k4 * u.x * u.y,
                du * vec2(k1 + k4 * u.y, k2 + k4 * u.x));
}

vec3 getWaterNormal(vec3 worldPos, float dist) {
    vec2 p = worldPos.xz;
    float t = frameTimeCounter * WATER_WAVE_SPEED;

    // Slightly rotated octaves, all drifting roughly in one wind direction
    vec2 grad = noiseD(p * 0.25 + vec2( t * 0.20,  t * 0.12)).yz * 0.25
              + noiseD(mat2(0.8, -0.6, 0.6, 0.8) * p * 0.55 + vec2( t * 0.28, -t * 0.10)).yz * (0.55 * 0.55)
              + noiseD(mat2(0.6, 0.8, -0.8, 0.6) * p * 1.20 + vec2(-t * 0.15,  t * 0.40)).yz * (1.20 * 0.28)
              + noiseD(p * 2.60 + vec2(t * 0.55, t * 0.35)).yz * (2.60 * 0.12);

    // Flatter in the distance -> no shimmering
    grad *= 0.30 * WATER_WAVE_STRENGTH / (1.0 + dist / 64.0);

    return normalize(vec3(-grad.x, 1.0, -grad.y));
}

// Water between surface and floor: x = along the view ray, y = vertically below the surface
vec2 getWaterThickness(vec3 waterViewPos) {
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float z = texture2D(depthtex1, uv).r;
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
    vec3 floorViewPos = p.xyz / p.w;

    float alongView = max(length(floorViewPos) - length(waterViewPos), 0.0);
    float vertical  = max((mat3(gbufferModelViewInverse) * (waterViewPos - floorViewPos)).y, 0.0);
    return vec2(alongView, vertical);
}

// Color + opacity of the water body (linear). vanilla = texture * biome color (linear)
vec4 getWaterAlbedo(vec4 vanilla, vec3 biomeTint, vec3 waterViewPos) {
    #if WATER_COLOR_MODE == 1
    vec3 waterCol = vec3(0.020, 0.110, 0.420); // BSL-like blue
    #else
    vec3 waterCol = biomeTint * 0.45;           // biome color (swamp green, warm ocean turquoise ...)
    #endif

    vec4 water = mix(vec4(waterCol, 0.60), vanilla, WATER_TEXTURE);
    water.a *= WATER_OPACITY;

    #ifdef WATER_DEPTH
    if (isEyeInWater == 0) {
        // Light has to go down and back up -> vertical depth counts too.
        // So walls right below the surface are slightly blue instead of bright white.
        vec2 thickness = getWaterThickness(waterViewPos);
        float absorb = 1.0 - exp(-(thickness.x * 0.14 + thickness.y * 0.3) * WATER_DEPTH_STRENGTH);
        water.a    = mix(max(water.a * 0.55, 0.32), 1.0, absorb); // clear at the shore, opaque in the depth
        water.rgb *= mix(1.0, 0.35, absorb);                      // darker in the depth
    }
    #endif

    return water;
}
#endif
