/*
    Tabby Shaders - Water (composite)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Runs after all translucent objects. Only water pixels are processed:
    - Refraction: the floor under water is distorted by the waves
    - Reflections: terrain via screen space reflections, otherwise sky
    - Sun/moon glint with sparkles on the waves
    Also (overworld): light shafts -> colortex3 (blurred and added in final)
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if defined LIGHT_SHAFTS && defined OVERWORLD
    #define USE_LIGHT_SHAFTS
#endif

varying vec2 texcoord;
varying vec3 sunVec;
varying vec3 upVec;
varying vec3 lightVec;
varying vec3 lightColor;

// =====================================================================
#ifdef VSH

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;

    sunVec     = normalize(sunPosition);
    upVec      = gbufferModelView[1].xyz;
    lightVec   = normalize(shadowLightPosition);
    lightColor = getDirectLightColor();
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/water.glsl"

#if defined USE_LIGHT_SHAFTS && defined SHADOWS
#include "/lib/shadows.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1; // depth without water/glass (floor below the water)
uniform mat4 gbufferProjection;

vec3 toView(vec2 uv, float z) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 toScreen(vec3 viewPos) {
    vec4 p = gbufferProjection * vec4(viewPos, 1.0);
    return p.xyz / p.w * 0.5 + 0.5;
}

#ifdef WATER_SSR
// Screen space reflection: growing step size + 4 refinement steps
// Returns: rgb = reflected color, a = confidence (0 = no hit)
vec4 traceReflection(vec3 viewPos, vec3 dir) {
    // Small first step: otherwise the ray jumps straight into the neighbor block at block edges
    vec3 stepV = dir * (0.15 + length(viewPos) * 0.015);
    vec3 pos = viewPos;

    for (int i = 0; i < SSR_STEPS; i++) {
        vec3 prev = pos;
        pos += stepV;
        if (pos.z > -0.05) break; // behind the camera

        vec3 sp = toScreen(pos);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) break;

        float sceneDepth = texture2D(depthtex0, sp.xy).r;
        if (sceneDepth < 0.56) break; // never reflect the hand

        float diff = toView(sp.xy, sceneDepth).z - pos.z; // > 0: ray is behind the scene
        // Only just behind the surface counts as a hit (otherwise "hits" through blocks)
        if (diff > 0.0 && diff < length(stepV) * 1.2 + 0.1) {
            vec3 a = prev;
            vec3 b = pos;
            for (int j = 0; j < 4; j++) {
                vec3 m = (a + b) * 0.5;
                vec3 msp = toScreen(m);
                if (toView(msp.xy, texture2D(depthtex0, msp.xy).r).z - m.z > 0.0) b = m;
                else a = m;
            }
            vec3 hit = toScreen(b);
            // After refinement the hit must really lie on the surface
            if (abs(toView(hit.xy, texture2D(depthtex0, hit.xy).r).z - b.z) > length(stepV) * 0.5 + 0.2) return vec4(0.0);
            vec2 edge = min(hit.xy, 1.0 - hit.xy);
            float fade = clamp(min(edge.x, edge.y) * 12.0, 0.0, 1.0); // soft at the screen edge
            return vec4(texture2D(colortex0, hit.xy).rgb, fade);
        }
        stepV *= 1.4;
    }
    return vec4(0.0);
}
#endif

#ifdef USE_LIGHT_SHAFTS
#include "/lib/dither.glsl"

vec3 getLightShafts(vec3 viewPos) {
    vec3 nView = normalize(viewPos);
    float VoL = dot(nView, lightVec);
    float dither = bayer8(gl_FragCoord.xy);

    // Forward scattering: bright towards the sun/moon, weak to the side
    float phase = 0.12 + 0.88 * pow(VoL * 0.5 + 0.5, 6.0);

    // Strong at sunrise/sunset, subtle at noon, not in caves
    float eyeSky = getEyeSkyLight();
    float strength = LIGHT_SHAFT_STRENGTH * mix(0.3, 1.0, twilight * twilight) * eyeSky * eyeSky;
    if (isEyeInWater == 1) strength = LIGHT_SHAFT_STRENGTH * 1.5 * (0.2 + 0.8 * eyeSky);

    #ifdef SHADOWS
    // Sample the shadow map along the view ray: fraction of lit air
    float maxDist = min(length(viewPos), isEyeInWater == 1 ? 32.0 : shadowDistance);
    vec3 start = gbufferModelViewInverse[3].xyz;
    vec3 end   = start + mat3(gbufferModelViewInverse) * nView * maxDist;
    vec3 sStart = (shadowProjection * (shadowModelView * vec4(start, 1.0))).xyz;
    vec3 sEnd   = (shadowProjection * (shadowModelView * vec4(end, 1.0))).xyz;

    float lit = 0.0;
    for (int i = 0; i < LIGHT_SHAFT_SAMPLES; i++) {
        float t = (float(i) + dither) / float(LIGHT_SHAFT_SAMPLES);
        vec3 p = distortShadow(mix(sStart, sEnd, t * t)) * 0.5 + 0.5; // more samples close to the camera
        lit += shadow2D(shadowtex1, p).x;
    }
    lit /= float(LIGHT_SHAFT_SAMPLES);
    float density = 1.0 - exp(-maxDist / (isEyeInWater == 1 ? 12.0 : 160.0));
    #else
    // Without shadow map: rays from visible sky around the sun (screen space method)
    vec4 lightClip = gbufferProjection * vec4(lightVec * 100.0, 1.0);
    if (lightClip.w <= 0.0) return vec3(0.0);
    vec2 lightUV = lightClip.xy / lightClip.w * 0.5 + 0.5;

    int samples = LIGHT_SHAFT_SAMPLES * 2;
    vec2 delta = (lightUV - texcoord) / float(samples);
    vec2 uv = texcoord + delta * dither;
    float lit = 0.0;
    for (int i = 0; i < LIGHT_SHAFT_SAMPLES * 2; i++) {
        lit += texture2D(depthtex0, clamp(uv, 0.0, 1.0)).r >= 1.0 ? 1.0 : 0.0;
        uv += delta;
    }
    lit /= float(samples);
    float density = exp(-length((lightUV - texcoord) * vec2(viewWidth / viewHeight, 1.0)) * 2.0) * 0.6;
    #endif

    vec3 shafts = lightColor * (lit * phase * density * strength);
    if (isEyeInWater == 1) shafts *= vec3(0.3, 0.8, 1.0);
    return shafts;
}
#endif

#ifdef USE_LIGHT_SHAFTS
/* DRAWBUFFERS:03 */
#else
/* DRAWBUFFERS:0 */
#endif
void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;
    vec4 data  = texture2D(colortex2, texcoord);
    vec3 info  = unpackWaterInfo(data.b); // x = water, y = sky light, z = shadow
    vec3 viewPos = toView(texcoord, texture2D(depthtex0, texcoord).r);

    if (info.x > 0.5 && isEyeInWater == 0) {
        // Water: alpha = 1. Puddles/wet surfaces: alpha = reflection strength * 0.5
        bool isWater = data.a > 0.75;
        float strength = isWater ? 1.0 : data.a * 2.0;
        vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 N = decodeNormal(data.rg);
        vec3 V = normalize(viewPos);
        float dist = length(viewPos);

        #ifdef WATER_REFRACTION
        if (isWater && dot(N, upVec) > 0.5) {
            // How much water lies below the surface here? Right at walls almost none ->
            // barely distort there, otherwise the bright wall gets pulled wavy into the water
            float surfaceDepth = texture2D(depthtex0, texcoord).r;
            float thickness = length(toView(texcoord, texture2D(depthtex1, texcoord).r)) - dist;
            float refrScale = clamp(thickness * 0.5, 0.0, 1.0);

            vec2 refrUV = texcoord + (N - upVec).xy * (0.12 * WATER_REFRACTION_STRENGTH * refrScale) / (1.0 + dist * 0.08);
            refrUV = clamp(refrUV, 0.0, 1.0);

            // Only distort if there is water there too and the floor there lies below the surface
            vec4 refrData = texture2D(colortex2, refrUV);
            bool targetIsWater = unpackWaterInfo(refrData.b).x > 0.5 && refrData.a > 0.75;
            bool targetBelow = texture2D(depthtex1, refrUV).r > surfaceDepth;
            if (targetIsWater && targetBelow) {
                color = texture2D(colortex0, refrUV).rgb;
            }
        }
        #endif

        #ifdef WATER_REFLECTIONS
        float NdotV = clamp(dot(N, -V), 0.0, 1.0);
        float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);
        vec3 R = reflect(V, N);

        #ifdef OVERWORLD
        vec3 refl = getSkyColor(R, sunVec, upVec);
        #else
        vec3 refl = getFogColor(R);
        #endif
        refl *= info.y * info.y; // no bright sky under roofs / in caves

        #ifdef WATER_SSR
        // Only for strong reflections (water, puddles) - wet walls only get the sky
        if (strength > 0.4) {
            vec4 ssr = traceReflection(viewPos, R);
            refl = mix(refl, ssr.rgb, ssr.a);
        }
        #endif

        applyFog(refl, viewPos, playerPos);
        color = mix(color, refl, fresnel * strength);
        #endif

        // Sun/moon glint (normalized Blinn-Phong with Fresnel)
        vec3 H = normalize(lightVec - V);
        float NdotH = max(dot(N, H), 0.0);
        float NdotL = max(dot(N, lightVec), 0.0);
        float fresnelH = 0.02 + 0.98 * pow(1.0 - max(dot(-V, H), 0.0), 5.0);
        float spec = 239.0 * pow(NdotH, 1500.0) * fresnelH * NdotL;
        spec *= info.z * strength * (1.0 - getBorderFog(dist));
        color += lightColor * spec;
    }

    gl_FragData[0] = vec4(color, 1.0);

    #ifdef USE_LIGHT_SHAFTS
    gl_FragData[1] = vec4(getLightShafts(viewPos), 1.0);
    #endif
}

#endif
