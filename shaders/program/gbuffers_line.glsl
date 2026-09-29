/*
    Tabby Shaders - Lines (block outline)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Iris runs line shaders in the core profile. There the shader has to widen the line to
    pixel width itself (like the vanilla line shader) - otherwise it is 0 pixels wide and invisible.
      gl_Normal      = direction of the line (towards the other end)
      Width like vanilla: 2.5 pixels at 1080p (Iris does not allow access to its internal line width)
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec4 vColor;
varying vec3 viewPos;
varying vec3 playerPos;

// =====================================================================
#ifdef VSH

const float VIEW_SHRINK = 1.0 - 1.0 / 256.0; // slightly towards the camera -> no z-fighting with the block

void main() {
    vColor    = gl_Color;
    viewPos   = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    // Start and end of the line on screen
    vec4 lineStart = gl_ProjectionMatrix * vec4(viewPos * VIEW_SHRINK, 1.0);
    vec4 lineEnd   = gl_ProjectionMatrix * vec4((gl_ModelViewMatrix * vec4(gl_Vertex.xyz + gl_Normal, 1.0)).xyz * VIEW_SHRINK, 1.0);

    vec2 screen = vec2(viewWidth, viewHeight);
    vec3 ndc1 = lineStart.xyz / lineStart.w;
    vec3 ndc2 = lineEnd.xyz / lineEnd.w;

    // Offset perpendicular to the line by half the width (every second vertex outwards)
    float width = max(2.5 * viewHeight / 1080.0, 1.0);
    vec2 dir = normalize((ndc2.xy - ndc1.xy) * screen);
    vec2 offset = vec2(-dir.y, dir.x) * width / screen;
    if (offset.x < 0.0) offset = -offset;

    if (gl_VertexID % 2 == 0) gl_Position = vec4((ndc1 + vec3(offset, 0.0)) * lineStart.w, lineStart.w);
    else                      gl_Position = vec4((ndc1 - vec3(offset, 0.0)) * lineStart.w, lineStart.w);
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

/* DRAWBUFFERS:0 */
void main() {
    vec4 col = vColor;
    col.rgb = toLinear(col.rgb);
    applyFog(col.rgb, viewPos, playerPos);
    gl_FragData[0] = col;
}

#endif
