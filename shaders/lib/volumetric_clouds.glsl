/*
    Tabby Shaders - Volumetric clouds
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Three styles (VC_STYLE):
      0 = Complementary Unbound style: realistic tall cumulus clouds with
          cauliflower tops, flat dark bottoms, multiple scattering and silver lining
      1 = BSL style: organic, soft cumulus clouds made of several noise octaves
      2 = Complementary Reimagined style: blocky cloud fields on the vanilla grid, softly rounded
    Raymarching at half resolution (scale.deferred = 0.5). Noise comes from noisetex
    (256x256 random values, smoothly filtered) -> one texture fetch per octave (3D: two).
    Requires: common.glsl, sky.glsl
*/

#include "/lib/noise.glsl"

uniform float cloudHeight;

#if VC_STYLE == 0
    const float VC_BASE_THICKNESS = 110.0; // blocks
    const float VC_EXTINCTION     = 0.06;  // cloud density per block
    const float VC_MAX_SEGMENT    = 1500.0;// max. distance through the cloud layer
    const float VC_WIND_SPEED     = 3.0;   // blocks per second
#elif VC_STYLE == 1
    const float VC_BASE_THICKNESS = 48.0;
    const float VC_EXTINCTION     = 0.09;
    const float VC_MAX_SEGMENT    = 1000.0;
    const float VC_WIND_SPEED     = 2.0;
#else
    const float VC_BASE_THICKNESS = 18.0;
    const float VC_EXTINCTION     = 0.22;
    const float VC_MAX_SEGMENT    = 600.0;
    const float VC_WIND_SPEED     = 0.6;   // like vanilla
#endif

const float VC_MAX_DISTANCE = 2500.0;

float getCloudBottom() {
    #if VC_HEIGHT > 0
    return float(VC_HEIGHT);
    #else
    float h = cloudHeight; // Iris: cloud height of the dimension
    if (h != h || abs(h) < 0.001) h = CLOUD_HEIGHT_FALLBACK;
    return h;
    #endif
}

#if VC_STYLE == 0
// ---------------------------------------------------------------------
//  Complementary Unbound style: cumulus
// ---------------------------------------------------------------------
float cloudDensity(vec3 p, float h, float coverage, vec2 wind) {
    if (h < 0.0 || h > 1.0) return 0.0;
    vec2 xz = p.xz + wind;

    // Weather map: where are clouds? (structures of a few hundred blocks)
    float weather = noiseSmooth(xz * 0.0028) * 0.65 + noiseSmooth(xz * 0.0075 + 50.0) * 0.35;
    float cov = smoothstep(1.0 - coverage - 0.10, 1.0 - coverage + 0.30, weather);
    if (cov <= 0.0) return 0.0;

    // Height profile: flat bottom, tall towers grow in dense areas
    float topH = mix(0.30, 1.0, cov);
    float grad = smoothstep(0.0, 0.06, h) * (1.0 - smoothstep(topH * 0.45, topH, h));
    float base = cov * grad;
    if (base < 0.01) return 0.0;

    // 3D shape: cauliflower tops, frayed bottom edge
    vec3 q = vec3(xz.x, p.y, xz.y) * 0.035;
    float n = noise3D(q) * 0.625 + noise3D(q * 2.7 + vec3(0.0, wind.x * 0.004, 0.0)) * 0.375;
    float erosion = mix(n, 1.0 - n, smoothstep(0.15, 0.6, h));

    return clamp((base - erosion * 0.55) * 2.2, 0.0, 1.0);
}

#elif VC_STYLE == 1
// ---------------------------------------------------------------------
//  BSL style
// ---------------------------------------------------------------------
float cloudDensity(vec3 p, float h, float coverage, vec2 wind) {
    if (h < 0.0 || h > 1.0) return 0.0;

    vec2 uv = (p.xz + wind) * 0.0045;
    float n = noiseSmooth(uv) * 0.55
            + noiseLinear(uv * 2.3 + vec2(h * 0.35, 0.0) - wind * 0.001).g * 0.28
            + noiseLinear(uv * 5.7 + wind * 0.002).b * 0.12
            + noiseLinear(uv * 13.1 - vec2(0.0, h * 0.8)).a * 0.05;

    // Domed shape: soft bottom, round tops
    float profile = smoothstep(0.0, 0.25, h) * (1.0 - smoothstep(0.35, 1.0, h));
    float d = n - (1.0 - coverage) - (1.0 - profile) * 0.35;

    return clamp(d * 4.0, 0.0, 1.0);
}

#else
// ---------------------------------------------------------------------
//  Complementary Reimagined style
// ---------------------------------------------------------------------

// Is this 12x12 cell cloudy? Coarse clusters + random single cells like the vanilla cloud texture
float cellOccupancy(vec2 cell, float coverage) {
    float cluster = noiseLinear((cell + 0.5) * 0.23).r;  // smooth -> connected fields
    float single  = noiseLinear(cell + 0.5).g;           // texel center -> random per cell
    float n = cluster * 0.7 + single * 0.3;
    return smoothstep(1.0 - coverage - 0.03, 1.0 - coverage + 0.03, n);
}

float cloudDensity(vec3 p, float h, float coverage, vec2 wind) {
    if (h < 0.0 || h > 1.0) return 0.0;

    vec2 q = (p.xz + wind) / 12.0 - 0.5;
    vec2 i = floor(q);
    vec2 s = smoothstep(0.15, 0.85, fract(q)); // blocky, but with round corners

    float o = mix(mix(cellOccupancy(i,                  coverage), cellOccupancy(i + vec2(1.0, 0.0), coverage), s.x),
                  mix(cellOccupancy(i + vec2(0.0, 1.0), coverage), cellOccupancy(i + vec2(1.0, 1.0), coverage), s.x), s.y);
    if (o < 0.01) return 0.0;

    // Flat bottom, rounded top (lower at the edges)
    float d = o - h * h * 0.9;
    d *= smoothstep(0.0, 0.06 + (1.0 - o) * 0.35, h);

    // Fluffy edges
    float detail = noiseLinear((p.xz + wind * 1.3) * 0.35 + vec2(p.y * 0.7, 0.0)).b;
    d -= detail * 0.28;

    return clamp(d * 3.0, 0.0, 1.0);
}
#endif

// Henyey-Greenstein, normalized to 1 = uniform scattering
float phaseHG(float g, float cosTheta) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}

// Volumetric clouds along a view ray.
// Returns: rgb = cloud light (premultiplied), a = opacity
// cloudDist = average distance of the visible cloud (for temporal smoothing)
vec4 getVolumetricClouds(vec3 viewPos, bool isSky, float dither, out float cloudDist) {
    vec3 viewDir  = normalize(viewPos);
    vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
    vec3 eyePos   = cameraPosition + gbufferModelViewInverse[3].xyz;

    float bottom = getCloudBottom();
    float top    = bottom + VC_BASE_THICKNESS * VC_THICKNESS;
    float maxDist = isSky ? VC_MAX_DISTANCE : min(length(viewPos), VC_MAX_DISTANCE);
    cloudDist = maxDist;

    // Intersections with the cloud layer
    float tEnter, tExit;
    if (abs(worldDir.y) < 1e-5) {
        if (eyePos.y < bottom || eyePos.y > top) return vec4(0.0);
        tEnter = 0.0;
        tExit  = maxDist;
    } else {
        float tA = (bottom - eyePos.y) / worldDir.y;
        float tB = (top    - eyePos.y) / worldDir.y;
        tEnter = max(min(tA, tB), 0.0);
        tExit  = min(max(tA, tB), maxDist);
    }
    tExit = min(tExit, tEnter + VC_MAX_SEGMENT);
    if (tExit <= tEnter) return vec4(0.0);
    cloudDist = tEnter;

    // --- Light: sun during the day, moon at night ---
    vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    bool isDay = sunVisibility >= moonVisibility;
    vec3 L = isDay ? sunDir : -sunDir;
    vec3 lightCol = isDay ? mix(SUN_COL_TWI, SUN_COL_DAY, timeBrightness) * (sunVisibility * 3.2 * SUN_BRIGHTNESS)
                          : MOON_COL * (0.15 * moonVisibility * NIGHT_BRIGHTNESS);
    lightCol *= 1.0 - rainStrength * 0.75;
    vec3 ambient = getAmbientColor() * 2.0;

    float VoL = dot(worldDir, L);
    #if VC_STYLE == 0
    // Uniform part + strong silver lining towards the sun + some back scattering
    float phase = 0.6 + mix(phaseHG(0.75, VoL), phaseHG(-0.20, VoL), 0.35) * 0.5;
    #else
    float VoLp = max(VoL, 0.0);
    float phase = 0.8 + 0.3 * VoLp * VoLp + 1.6 * pow(VoLp, 8.0);
    #endif

    float coverage = clamp(VC_AMOUNT + rainStrength * 0.25, 0.0, 0.95);
    vec2 wind = vec2(frameTimeCounter * VC_WIND_SPEED * VC_SPEED, 0.0);
    float thickness = top - bottom;

    // --- Raymarching (front to back) ---
    // Step size based on cloud thickness: steep views need few steps,
    // flat views towards the horizon need more (at most double the quality)
    float pathLen = tExit - tEnter;
    float steps = clamp(ceil(pathLen / (thickness / (float(VC_QUALITY) * 0.5))), 4.0, float(VC_QUALITY * 2));
    float stepLen = pathLen / steps;
    float t = tEnter + stepLen * dither;
    float transmittance = 1.0;
    vec3 scatter = vec3(0.0);
    float distSum = 0.0;
    float distWeight = 0.0;

    for (int i = 0; i < VC_QUALITY * 2; i++) {
        if (float(i) >= steps) break;
        vec3 p = eyePos + worldDir * t;
        float h = (p.y - bottom) / thickness;
        float d = cloudDensity(p, h, coverage, wind);

        if (d > 0.001) {
            #if VC_STYLE == 0
            // Two steps towards the sun (short + long)
            vec3 lp1 = p + L * 10.0;
            vec3 lp2 = p + L * 38.0;
            float ld = cloudDensity(lp1, (lp1.y - bottom) / thickness, coverage, wind) * 10.0
                     + cloudDensity(lp2, (lp2.y - bottom) / thickness, coverage, wind) * 28.0;
            float opticalDepth = (ld + d * 5.0) * VC_EXTINCTION;
            // Multiple scattering (simplified): the inside stays bright instead of black
            float sunT = exp(-opticalDepth) * 0.65 + exp(-opticalDepth * 0.25) * 0.35;
            // "Powder": edges facing the sun slightly darker -> sculpted look
            float powder = 1.0 - exp(-d * 6.0) * 0.6;
            vec3 radiance = lightCol * sunT * phase * powder
                          + ambient * mix(0.25, 1.1, sqrt(h));
            #else
            // One step towards the light: how much cloud is in front?
            float lightStep = thickness * 0.25;
            vec3 lp = p + L * lightStep;
            float ld = cloudDensity(lp, (lp.y - bottom) / thickness, coverage, wind);
            float sunT = exp(-(ld + d * 0.5) * lightStep * VC_EXTINCTION);
            vec3 radiance = lightCol * sunT * phase + ambient * mix(0.35, 1.0, h);
            #endif

            float stepT = exp(-d * stepLen * VC_EXTINCTION);
            float contribution = transmittance * (1.0 - stepT);
            scatter += contribution * radiance;
            distSum += contribution * t;
            distWeight += contribution;
            transmittance *= stepT;
            if (transmittance < 0.02) break;
        }
        t += stepLen;
    }

    if (distWeight > 1e-4) cloudDist = distSum / distWeight;

    float alpha = 1.0 - transmittance;
    if (alpha < 0.001) return vec4(0.0);

    // Distant clouds fade into the sky
    vec3 sky = getSkyColor(viewDir, normalize(sunPosition), gbufferModelView[1].xyz);
    float haze = 1.0 - exp(-tEnter / 2500.0);
    scatter = mix(scatter, sky * alpha, haze * 0.7);
    float fade = (1.0 - smoothstep(VC_MAX_DISTANCE * 0.45, VC_MAX_DISTANCE, tEnter)) * (1.0 - max(blindness, darknessFactor));

    return vec4(scatter, alpha) * fade;
}
