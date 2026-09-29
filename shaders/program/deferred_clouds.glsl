/*
    Tabby Shaders - Volumetric clouds, step 1: raw image (deferred, half resolution)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Thanks to "scale.deferred = 0.5" only a quarter of the pixels is rendered (bottom left).
      colortex4 = clouds (rgb premultiplied, a = opacity), noisy due to moving dithering
      colortex6 = average cloud distance (for the smoothing in deferred1)
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

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

#include "/lib/sky.glsl"
#include "/lib/dither.glsl"
#include "/lib/volumetric_clouds.glsl"

uniform sampler2D depthtex0;

/* DRAWBUFFERS:46 */
void main() {
    float depth = texture2D(depthtex0, texcoord).r;

    // Hand (Iris compresses its depth below 0.56): no clouds
    if (depth < 0.56) {
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(0.0);
        return;
    }

    bool isSky = depth >= 1.0;
    vec4 viewPos = gbufferProjectionInverse * vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0);
    viewPos.xyz /= viewPos.w;

    // Dither moves on every frame (golden ratio) -> deferred1 averages the noise away
    float dither = fract(bayer8(gl_FragCoord.xy) + float(frameCounter) * 0.618034);

    float cloudDist;
    gl_FragData[0] = getVolumetricClouds(viewPos.xyz, isSky, dither, cloudDist);
    gl_FragData[1] = vec4(cloudDist, 0.0, 0.0, 1.0);
}

#endif
