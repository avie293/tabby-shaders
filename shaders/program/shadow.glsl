/*
    Tabby Shaders - Shadow pass
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Runs when shadows or colored lighting are enabled.
    Also writes the blocks into the voxel volume for colored lighting.
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec4 vColor;
varying vec2 texcoord;

// =====================================================================
#ifdef VSH

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform int renderStage;

#include "/lib/shadows.glsl"
#include "/lib/waving.glsl"

#ifdef USE_COLORED_LIGHTING
#include "/lib/voxel.glsl"

attribute vec4 at_midBlock; // Iris: offset to the block center * 64 (terrain only)
layout(r8ui) writeonly uniform uimage3D voxelImg;

// 0 = transparent to light, 1 = solid block, 2..15 = light source, 16..31 = stained glass, 40..48 = ores
uint getVoxelType(int id) {
    if (id >= 10101 && id <= 10114) return uint(id - 10099);
    if (id >= 10201 && id <= 10216) return uint(id - 10185);
    if (id >= 10130 && id <= 10138) return uint(id - 10090); // glowing ores -> 40..48
    if (id == 10140) return 8u;                                // nether portal: purple light
    if (id >= 10001 && id <= 10010) return 0u; // plants, leaves, glass, fences, water ...
    return 1u;
}

void writeVoxel(vec3 playerPos, int id) {
    if (dot(at_midBlock.xyz, at_midBlock.xyz) < 0.01) return; // entities have no at_midBlock
    uint type = getVoxelType(id);
    if (type == 0u) return;

    ivec3 vp = ivec3(floor(playerToVoxel(playerPos + at_midBlock.xyz / 64.0)));
    if (any(lessThan(vp, ivec3(0))) || any(greaterThanEqual(vp, VOXEL_SIZE))) return;
    imageStore(voxelImg, vp, uvec4(type, 0u, 0u, 0u));
}
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor   = gl_Color;

    vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos  = (shadowModelViewInverse * vec4(shadowView, 1.0)).xyz;
    int id = int(mc_Entity.x + 0.5);

    #ifdef USE_COLORED_LIGHTING
    writeVoxel(playerPos, id);
    #endif

    #if defined WAVING_PLANTS || defined WAVING_LEAVES
    // Same movement as in the terrain shader, otherwise the shadows "swim"
    if (id >= 10001 && id <= 10003) {
        float skyLight = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).y - 0.03125) * 1.06667, 0.0, 1.0);
        playerPos += getWavingOffset(playerPos + cameraPosition, id, texcoord.y < mc_midTexCoord.y, skyLight);
        shadowView = (shadowModelView * vec4(playerPos, 1.0)).xyz;
    }
    #endif

    gl_Position = gl_ProjectionMatrix * vec4(shadowView, 1.0);
    gl_Position.xyz = distortShadow(gl_Position.xyz);

    // Translucent blocks (glass, water, ice) are only needed for colored lighting,
    // not for the shadow map -> move them off screen, saves pixel work
    #ifdef MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
    if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) gl_Position = vec4(-10.0, -10.0, -10.0, 1.0);
    #endif
    if (id == 10010) gl_Position = vec4(-10.0, -10.0, -10.0, 1.0);
}

#endif

// =====================================================================
#ifdef FSH

uniform sampler2D gtexture;

void main() {
    vec4 col = texture2D(gtexture, texcoord) * vColor;
    if (col.a < 0.1) discard;
    gl_FragData[0] = col;
}

#endif
