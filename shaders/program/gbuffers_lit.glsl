/*
    Tabby Shaders - Lit geometry (forward rendering)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Used by: terrain, water, entities, block, hand, textured (particles), weather
    Control defines: TERRAIN, WATER_PROGRAM, ENTITIES, BLOCK_ENTITIES, HAND, PARTICLES, WEATHER
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if defined SHADOWS && (defined OVERWORLD || defined END) && !defined WEATHER
    #define USE_SHADOWS
#endif

#if defined PBR && !defined PARTICLES && !defined WEATHER
    #define USE_PBR
#endif

varying vec4 vColor;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 viewPos;
varying vec3 playerPos;
varying vec3 normal;
varying vec3 lightCol;
varying vec3 ambientCol;
varying float materialId;

#ifdef USE_PBR
varying vec4 tangentV; // tangent (view space) + bitangent direction
#endif

#ifdef USE_SHADOWS
varying vec3 shadowClipPos;
#include "/lib/shadows.glsl"
#endif

// =====================================================================
#ifdef VSH

// Same math -> exactly the same depth as in the glint shader (otherwise the enchantment glint is missing)
invariant gl_Position;

#if defined TERRAIN || defined WATER_PROGRAM
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
#include "/lib/waving.glsl"
#endif

#ifdef USE_PBR
attribute vec4 at_tangent;
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    vColor   = gl_Color;

    viewPos   = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    normal    = normalize(gl_NormalMatrix * gl_Normal);

    #ifdef USE_PBR
    tangentV = vec4(gl_NormalMatrix * at_tangent.xyz, at_tangent.w);
    #endif

    materialId = 0.0;

    #if defined TERRAIN || defined WATER_PROGRAM
    materialId = mc_Entity.x;
    int id = int(materialId + 0.5);

    #ifdef TERRAIN
    vec3 wave = getWavingOffset(playerPos + cameraPosition, id, texcoord.y < mc_midTexCoord.y, lmcoord.y);
    playerPos += wave;
    viewPos   += mat3(gbufferModelView) * wave;
    #endif

    // Plants: flat lighting from above (no hard edges on grass/flowers)
    if (id >= 10001 && id <= 10005) normal = gbufferModelView[1].xyz;
    #endif

    #if defined PARTICLES || defined WEATHER
    normal = gbufferModelView[1].xyz;
    #endif

    gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

    lightCol   = getDirectLightColor();
    ambientCol = getAmbientColor();

    #ifdef USE_SHADOWS
    shadowClipPos = getShadowClipPos(playerPos, mat3(gbufferModelViewInverse) * normal);
    #endif
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;

// Reflection data to colortex2 (for composite): puddles, wet surfaces, smooth PBR surfaces.
// Entities/block entities clear the mask (otherwise a mob standing in a puddle gets reflections).
#if (defined TERRAIN || defined ENTITIES || defined BLOCK_ENTITIES) && ((defined WET_SURFACES && defined OVERWORLD) || defined USE_PBR)
    #define WRITES_REFLECT_DATA
#endif
#if defined TERRAIN && defined WET_SURFACES && defined OVERWORLD
    #define USE_WET
#endif
#if defined USE_WET || (defined WATER_PROGRAM && defined RAIN_RIPPLES && defined OVERWORLD)
    #define NEEDS_WEATHER
#endif
#if defined FANCY_PORTALS && (defined WATER_PROGRAM || defined BLOCK_ENTITIES)
    #define NEEDS_PORTALS
#endif

#if defined WATER_PROGRAM || defined HAND || defined WRITES_REFLECT_DATA
#include "/lib/water.glsl"
#endif
#if defined NEEDS_WEATHER || defined NEEDS_PORTALS
#include "/lib/noise.glsl"
#endif
#ifdef NEEDS_WEATHER
#include "/lib/weather.glsl"
#endif
#ifdef NEEDS_PORTALS
#include "/lib/portals.glsl"
#endif
#ifdef USE_COLORED_LIGHTING
#include "/lib/voxel.glsl"
#endif
#ifdef USE_PBR
#include "/lib/pbr.glsl"
#endif

#ifdef DYNAMIC_HANDLIGHT
#include "/lib/light_colors.glsl"
uniform int heldItemId;
uniform int heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

#ifdef ENTITIES
uniform vec4 entityColor;
#endif
#ifdef BLOCK_ENTITIES
uniform int blockEntityId;
#endif

// Water/reflection data additionally goes to colortex2 (for the composite pass).
// The hand clears the mask so it gets no reflections.
#if defined WATER_PROGRAM || defined HAND || defined WRITES_REFLECT_DATA
/* DRAWBUFFERS:02 */
#else
/* DRAWBUFFERS:0 */
#endif
void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * vColor;

    #ifdef WEATHER
    albedo.a *= RAIN_OPACITY;
    #endif

    vec3 albedoGamma = albedo.rgb;
    albedo.rgb = toLinear(albedo.rgb);

    #ifdef ENTITIES
    // red when hurt, white when a creeper flashes
    albedo.rgb = mix(albedo.rgb, toLinear(entityColor.rgb), entityColor.a);
    #endif

    int id = int(materialId + 0.5);
    vec3 N      = normalize(normal); // face normal
    vec3 worldN = mat3(gbufferModelViewInverse) * N;
    vec3 L      = normalize(shadowLightPosition);
    vec3 V      = normalize(viewPos);
    vec3 upVec  = gbufferModelView[1].xyz;

    bool flatLit = id >= 10001 && id <= 10005;
    #if defined PARTICLES || defined WEATHER
    flatLit = true;
    #endif

    // --- PBR (labPBR): normal map, material AO, smoothness, metal, emission ---
    vec3 Nm = N; // normal for lighting (with normal map)
    float materialAO = 1.0;
    float smoothness = 0.0;
    float f0 = 0.02;
    bool metal = false;
    float pbrEmission = 0.0;
    #ifdef USE_PBR
    bool usePBR = !flatLit;
    #ifdef WATER_PROGRAM
    usePBR = usePBR && id != 10010 && id != 10140;
    #endif
    if (usePBR) {
        Nm = getPBRNormal(N, tangentV, texcoord, materialAO);
        getPBRMaterial(texcoord, smoothness, f0, metal, pbrEmission);
    }
    #endif
    float upDot = dot(Nm, upVec);

    // --- Reflection data for composite ---
    float reflectStrength = 0.0;
    vec3 reflectN = Nm;

    // --- Wet surfaces and puddles (only under open sky, only where it rains) ---
    #ifdef USE_WET
    float wet = getWetness() * smoothstep(0.88, 0.97, lmcoord.y);
    if (wet > 0.001) {
        vec2 worldXZ = playerPos.xz + cameraPosition.xz;
        float puddle = (!flatLit && worldN.y > 0.9) ? getPuddleMask(worldXZ, wet) : 0.0;

        // Wet surfaces are darker, a bit more under puddles
        albedo.rgb *= mix(1.0, 0.72, wet) * mix(1.0, 0.8, puddle);

        #ifdef RAIN_RIPPLES
        float rain = getRainHere();
        if (puddle > 0.05 && rain > 0.01) {
            vec2 g = getRainRipples(worldXZ) * rain;
            reflectN = mat3(gbufferModelView) * normalize(vec3(-g.x, 1.0, -g.y));
        } else if (puddle > 0.05) {
            reflectN = N; // puddles are smooth, even on normal maps
        }
        #endif

        // Puddles reflect strongly, wet surfaces only slightly
        if (!flatLit) reflectStrength = max(puddle, wet * (worldN.y > 0.5 ? 0.3 : 0.15));
    }
    #endif

    // --- Water ---
    #ifdef WATER_PROGRAM
    bool isWater = id == 10010;
    vec3 waterN = N;
    if (isWater) {
        albedo = getWaterAlbedo(albedo, toLinear(vColor.rgb), viewPos);

        if (worldN.y > 0.5) {
            vec3 wN = vec3(0.0, 1.0, 0.0);
            #ifdef WATER_WAVES
            wN = getWaterNormal(playerPos + cameraPosition, length(viewPos));
            #endif

            // Raindrop ripples on the water
            #if defined RAIN_RIPPLES && defined OVERWORLD
            float rain = getRainHere();
            if (rain > 0.01) {
                vec2 g = getRainRipples(playerPos.xz + cameraPosition.xz) * rain;
                wN = normalize(wN + vec3(-g.x, 0.0, -g.y));
            }
            #endif

            waterN = mat3(gbufferModelView) * wN;
        }
    }
    #endif

    // --- Direct light (sun/moon) with shadows ---
    float NdotL = max(dot(Nm, L), 0.0) * step(0.0, dot(N, L)); // normal map, but no back faces
    if (flatLit) NdotL = 0.35 + 0.65 * max(dot(N, L), 0.0);

    // Without shadow map: direct light only where a lot of sky light arrives
    #ifdef END
    float skyShadow = 1.0; // the End has no sky light in the lightmap
    #else
    float skyShadow = smoothstep(0.80, 0.97, lmcoord.y);
    #endif
    float shadow = skyShadow;

    #ifdef USE_SHADOWS
    if (NdotL > 0.0) {
        float fade = clamp((length(playerPos) - shadowDistance * 0.8) / (shadowDistance * 0.2), 0.0, 1.0);
        if (fade < 1.0) shadow = mix(sampleShadow(shadowClipPos), skyShadow, fade);
        #ifndef END
        // No sunlight deep in caves
        shadow *= min(lmcoord.y * 4.0, 1.0);
        #endif
    }
    #endif

    // --- Colored lighting: brightness from the lightmap, hue from the voxel light ---
    vec3 blockCol = BLOCKLIGHT_COL;
    #ifdef USE_COLORED_LIGHTING
    float oreLight = 0.0;
    vec4 colored = vec4(0.0);
    #ifdef GLOWING_ORES
    // ore light is only visible in dark places -> skip the 3D texture fetch in daylight
    if (lmcoord.x > 0.01 || lmcoord.y < 0.9) colored = getColoredLight(playerPos, worldN, oreLight);
    #else
    if (lmcoord.x > 0.01) colored = getColoredLight(playerPos, worldN, oreLight);
    #endif
    if (lmcoord.x > 0.01) {
        vec3 tinted = colored.rgb * (luminance(BLOCKLIGHT_COL) / max(luminance(colored.rgb), 0.4));
        blockCol = mix(BLOCKLIGHT_COL, tinted, colored.a);
    }
    #endif

    // --- Dynamic hand light: glowing items in the hand (1 light level per block) ---
    vec2 lm = lmcoord;
    #ifdef DYNAMIC_HANDLIGHT
    float handLevel = float(max(heldBlockLightValue, heldBlockLightValue2));
    if (handLevel > 0.5) {
        float handLight = clamp((handLevel * HANDLIGHT_RANGE - length(playerPos)) / 15.0, 0.0, 1.0);
        if (handLight > 0.0) {
            // Color of the brighter of both items (soul torch blue, redstone torch red ...)
            int handId = heldBlockLightValue >= heldBlockLightValue2 ? heldItemId : heldItemId2;
            vec3 handCol = BLOCKLIGHT_COL;
            if (handId >= 10101 && handId <= 10114) {
                vec3 c = getEmitterColor(handId - 10099);
                handCol = c * (luminance(BLOCKLIGHT_COL) / max(luminance(c), 0.4));
            }
            blockCol = mix(blockCol, handCol, handLight / max(handLight + lm.x, 1e-4));
            lm.x = max(lm.x, handLight);
        }
    }
    #endif

    vec3 light = getLighting(lm, NdotL * shadow, upDot, lightCol, ambientCol, blockCol);

    #if defined NETHER && defined NETHER_LAVA_GLOW
    // Orange light from the lava ocean (y ~ 31) - especially on downward facing surfaces
    float lavaGlow = exp(-max(playerPos.y + cameraPosition.y - 31.0, 0.0) / 16.0);
    light += LAVA_GLOW_COL * (0.35 * lavaGlow * (0.75 - 0.25 * upDot));
    #endif

    light *= mix(1.0, materialAO, 0.8);

    // Metals have hardly any diffuse color - they live from reflections
    vec3 color = (metal ? albedo.rgb * 0.15 : albedo.rgb) * light;

    // --- Light from nearby glowing ores ---
    #if defined USE_COLORED_LIGHTING && defined GLOWING_ORES
    color += albedo.rgb * colored.rgb * (oreLight * 0.8 * ORE_GLOW_STRENGTH);
    #endif

    // --- PBR: specular highlight and reflection ---
    #ifdef USE_PBR
    if (smoothness > 0.02 || metal) {
        float roughness = (1.0 - smoothness) * (1.0 - smoothness);
        vec3 F0 = metal ? albedo.rgb : vec3(f0);

        // Very smooth, non-metallic surfaces get real reflections (SSR) in the composite pass
        bool useSSR = false;
        #ifdef WRITES_REFLECT_DATA
        if (!metal && smoothness >= 0.8) {
            useSSR = true;
            if (smoothness > reflectStrength) {
                reflectStrength = smoothness;
                reflectN = Nm;
            }
        }
        #endif

        if (!useSSR) {
            color += lightCol * shadow * getSpecularHighlight(Nm, V, L, roughness, F0);

            // Sky reflection: rough surfaces reflect less
            vec3 R = reflect(V, Nm);
            #ifdef OVERWORLD
            vec3 skyRefl = getSkyColor(R, normalize(sunPosition), upVec) * (lm.y * lm.y);
            #else
            vec3 skyRefl = getFogColor(R);
            #endif
            color += skyRefl * fresnelSchlick(F0, dot(Nm, -V)) * (smoothness * smoothness);
        }
    }
    if (pbrEmission > 0.0) color += albedo.rgb * (pbrEmission * 2.0 * EMISSIVE_STRENGTH);
    #endif

    // --- Emissive blocks ---
    #ifdef EMISSIVE_BLOCKS
    if (id == 10106) {
        // Lava & magma glow completely
        color += albedo.rgb * (2.0 * EMISSIVE_STRENGTH);
    } else if (id >= 10101 && id <= 10114) {
        // Only bright pixels glow (e.g. the flame of a torch, not the stick)
        float e = max(albedoGamma.r, max(albedoGamma.g, albedoGamma.b));
        e *= e;
        color += albedo.rgb * (e * e * 4.0 * EMISSIVE_STRENGTH);
    }
    #endif

    // --- Glowing ores: only the colored ore spots, not the stone ---
    #ifdef GLOWING_ORES
    if (id >= 10130 && id <= 10136) {
        float maxC = max(albedoGamma.r, max(albedoGamma.g, albedoGamma.b));
        float minC = min(albedoGamma.r, min(albedoGamma.g, albedoGamma.b));
        float saturation = (maxC - minC) / max(maxC, 0.001);
        float e = smoothstep(0.2, 0.45, saturation) * maxC * maxC;
        color += albedo.rgb * (e * 2.0 * ORE_GLOW_STRENGTH);
    } else if (id >= 10137 && id <= 10138) {
        // Nether ores: quartz/gold are brighter than the red netherrack around them
        float e = smoothstep(0.45, 0.7, luminance(albedoGamma));
        color += albedo.rgb * (e * 2.0 * ORE_GLOW_STRENGTH);
    }
    #endif

    // --- 3D portals ---
    #ifdef NEEDS_PORTALS
    #ifdef WATER_PROGRAM
    if (id == 10140) {
        color = getNetherPortal(albedo.rgb, playerPos, worldN);
        albedo.a = max(albedo.a, 0.85);
    }
    #else
    if (blockEntityId == 10150) {
        color = getEndPortal(playerPos, worldN);
        albedo.a = 1.0;
    }
    #endif
    #endif

    #ifndef HAND
    applyFog(color, viewPos, playerPos);
    #endif

    gl_FragData[0] = vec4(color, albedo.a);

    // Alpha = 1 -> replaces the old content even with blending enabled
    #if defined WATER_PROGRAM
    if (isWater) gl_FragData[1] = vec4(encodeNormal(waterN), packWaterInfo(lmcoord.y, shadow), 1.0);
    else         gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
    #elif defined HAND
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
    #elif defined WRITES_REFLECT_DATA
    // Alpha = reflection strength * 0.5 (water uses 1.0). No reflection -> clear the mask
    if (reflectStrength > 0.004) gl_FragData[1] = vec4(encodeNormal(reflectN), packWaterInfo(lmcoord.y, shadow), reflectStrength * 0.5);
    else                         gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
    #endif
}

#endif
