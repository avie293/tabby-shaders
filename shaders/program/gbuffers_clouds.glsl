/*
    Tabby Shaders - Vanilla clouds with an upward fade
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    The shape stays vanilla. The clouds are opaque at the bottom and become transparent towards the top.
    Color follows the time of day (white by day, orange/pink at sunset, dark blue at night).
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec4 vColor;
varying vec3 viewPos;
varying vec3 playerPos;
varying vec3 normal;

// =====================================================================
#ifdef VSH

void main() {
    viewPos   = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    normal    = gl_NormalMatrix * gl_Normal; // safely normalized in the fragment shader
    vColor    = gl_Color;

    gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

uniform float cloudHeight; // Iris: cloud height of the current dimension

/* DRAWBUFFERS:0 */
void main() {
    vec3 sunVec = normalize(sunPosition);
    vec3 upVec  = gbufferModelView[1].xyz;

    float nLen = length(normal);
    vec3 N = nLen > 0.01 ? normal / nLen : upVec;

    // --- Lighting ---
    vec3 L = normalize(shadowLightPosition);
    float NdotL = dot(N, L) * 0.5 + 0.5;
    float upDot = dot(N, upVec);

    vec3 ambient = getAmbientColor() * 1.6;
    vec3 direct  = getDirectLightColor() * (0.45 + 0.55 * NdotL);
    // Vanilla-like face shading: bright on top, darker below
    float faceShade = 0.82 + 0.18 * upDot;
    vec3 color = (ambient + direct) * faceShade;

    // --- Upward fade ---
    float base = cloudHeight;
    if (base != base || abs(base) < 0.001) base = CLOUD_HEIGHT_FALLBACK; // NaN or not available
    float worldY = playerPos.y + cameraPosition.y;
    float h = clamp((worldY - base) / CLOUD_THICKNESS, 0.0, 1.0);
    h = h * h * (3.0 - 2.0 * h);
    float alpha = vColor.a * CLOUD_OPACITY * (1.0 - CLOUD_FADE * pow(h, CLOUD_FADE_CURVE));

    // --- Blend into the sky in the distance ---
    float dist = length(viewPos);
    vec3 viewDir = viewPos / max(dist, 1e-4);
    float horizDist = length(playerPos.xz) / (far * CLOUD_DISTANCE);
    alpha *= 1.0 - smoothstep(0.35, 1.0, horizDist);

    vec3 skyCol = getSkyColor(viewDir, sunVec, upVec);
    float haze = getAtmosphericFog(dist * 0.5, base);
    color = mix(color, skyCol, clamp(haze + horizDist * 0.4, 0.0, 0.9));

    // Blindness / darkness
    alpha *= 1.0 - max(blindness, darknessFactor);

    gl_FragData[0] = vec4(color, alpha);
}

#endif
