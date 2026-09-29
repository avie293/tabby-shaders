/*
    Tabby Shaders - Final
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    HDR -> screen: exposure, tonemapping, saturation, vignette, gamma.

    Buffer settings (read by Iris from the comment below):
*/
/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA8;
const bool colortex1Clear = true;
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex2Format = RGBA16;
const bool colortex2Clear = true;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex3Format = R11F_G11F_B10F;
const bool colortex3Clear = true;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex4Format = RGBA16F;
const bool colortex4Clear = false;
const int colortex5Format = RGBA16F;
const bool colortex5Clear = false;
const int colortex6Format = R16F;
const bool colortex6Clear = false;
*/

#include "/lib/settings.glsl"

varying vec2 texcoord;

// =====================================================================
#ifdef VSH

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
}

#endif

// =====================================================================
#ifdef FSH

uniform sampler2D colortex0;

#if defined LIGHT_SHAFTS && defined OVERWORLD
uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;
#endif

// ACES approximation (Narkowicz) - contrasty, cheap
vec3 tonemapACES(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

    #if defined LIGHT_SHAFTS && defined OVERWORLD
    // Light shafts: blur with 4 samples (removes the dither pattern)
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 shafts = texture2D(colortex3, texcoord + vec2( 1.5,  0.5) * px).rgb
                + texture2D(colortex3, texcoord + vec2(-1.5, -0.5) * px).rgb
                + texture2D(colortex3, texcoord + vec2( 0.5, -1.5) * px).rgb
                + texture2D(colortex3, texcoord + vec2(-0.5,  1.5) * px).rgb;
    color += shafts * 0.25;
    #endif

    color *= EXPOSURE;

    color = tonemapACES(color);

    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = max(mix(vec3(lum), color, SATURATION), 0.0);

    #ifdef VIGNETTE
    vec2 v = texcoord - 0.5;
    color *= 1.0 - dot(v, v) * VIGNETTE_STRENGTH * 1.6;
    #endif

    color = pow(color, vec3(1.0 / 2.2));

    gl_FragData[0] = vec4(color, 1.0);
}

#endif
