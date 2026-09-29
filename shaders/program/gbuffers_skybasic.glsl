/*
    Tabby Shaders - Vanilla sky (stars)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Overworld: only the stars are written to colortex1. Sky gradient, sun and moon
    are computed in the deferred pass for every sky pixel (independent of the vanilla sky mesh).
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec4 vColor;

// =====================================================================
#ifdef VSH

void main() {
    gl_Position = ftransform();
    vColor = gl_Color;
}

#endif

// =====================================================================
#ifdef FSH

uniform int renderStage;

#ifdef OVERWORLD
/* DRAWBUFFERS:1 */
void main() {
    #ifdef SHADER_STARS
    discard; // custom stars in the sky pass instead of vanilla squares
    #endif

    #ifdef MC_RENDER_STAGE_STARS
    if (renderStage != MC_RENDER_STAGE_STARS) discard;
    float starFade = (1.0 - sunVisibility) * (1.0 - rainStrength);
    gl_FragData[0] = vec4(vColor.rgb * vColor.a * starFade * min(STAR_BRIGHTNESS, 1.0), 1.0);
    #else
    discard;
    #endif
}
#else
/* DRAWBUFFERS:0 */
void main() {
    gl_FragData[0] = vec4(toLinear(vColor.rgb), vColor.a);
}
#endif

#endif
