/*
    Tabby Shaders - Textured sky (vanilla sun/moon, custom sky, end sky)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Overworld: -> colortex1 (added to the sky in the deferred pass)
    End:      discarded (custom storm sky in deferred2)
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec4 vColor;
varying vec2 texcoord;

// =====================================================================
#ifdef VSH

void main() {
    gl_Position = ftransform();
    vColor   = gl_Color;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif

// =====================================================================
#ifdef FSH

uniform sampler2D gtexture;
uniform int renderStage;

#ifdef OVERWORLD
/* DRAWBUFFERS:1 */
void main() {
    #if defined ROUND_SUN_MOON && defined MC_RENDER_STAGE_SUN
    // Round sun/moon are drawn in the deferred pass
    if (renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON) discard;
    #endif

    gl_FragData[0] = texture2D(gtexture, texcoord) * vColor;
}
#elif defined END
/* DRAWBUFFERS:0 */
void main() {
    discard; // custom end sky with storms in the sky pass (deferred2)
}
#else
/* DRAWBUFFERS:0 */
void main() {
    vec4 col = texture2D(gtexture, texcoord) * vColor;
    gl_FragData[0] = vec4(toLinear(col.rgb), col.a);
}
#endif

#endif
