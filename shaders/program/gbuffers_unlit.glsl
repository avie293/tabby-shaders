/*
    Tabby Shaders - Unlit geometry
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Control defines:
        NO_TEXTURE  -> vertex color only (lines, lightning)
        DAMAGED     -> block breaking cracks (multiplicative blending, so no conversion)
        GLINT       -> enchantment glint (added, so no fog)
        GLOW_MULT   -> brightness factor for glowing things
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifndef GLOW_MULT
    #define GLOW_MULT 1.0
#endif

varying vec4 vColor;
varying vec2 texcoord;
varying vec3 viewPos;
varying vec3 playerPos;

// =====================================================================
#ifdef VSH

// Same math as in the main program -> the glint lies exactly on the item
invariant gl_Position;

void main() {
    viewPos   = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vColor    = gl_Color;
    texcoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

uniform sampler2D gtexture;

/* DRAWBUFFERS:0 */
void main() {
    #ifdef NO_TEXTURE
    vec4 col = vColor;
    #else
    vec4 col = texture2D(gtexture, texcoord) * vColor;
    #endif

    #ifdef DAMAGED
    gl_FragData[0] = col;
    #else
    col.rgb = toLinear(col.rgb) * GLOW_MULT;
    #ifndef GLINT
    applyFog(col.rgb, viewPos, playerPos); // glint is added -> fog would only brighten it
    #endif
    gl_FragData[0] = col;
    #endif
}

#endif
