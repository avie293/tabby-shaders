/*
    Tabby Shaders - Sky (deferred)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Runs after the opaque terrain and before water/glass.
    Only pixels without geometry (depth = 1) get the sky -> very cheap.
    Overworld: gradient + round sun/moon + stars, then volumetric clouds (colortex5)
    Nether:   fog color
    End:      storm sky
    Runs as deferred2 in all dimensions (deferred/deferred1 = clouds at half resolution + smoothing,
    overworld only). Do not rename: scale.deferred/scale.deferred1 apply to all dimensions!
*/

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

varying vec2 texcoord;
varying vec3 sunVec;
varying vec3 upVec;
varying vec3 eastVec;

// =====================================================================
#ifdef VSH

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;

    sunVec  = normalize(sunPosition);
    upVec   = gbufferModelView[1].xyz;
    eastVec = gbufferModelView[0].xyz;
}

#endif

// =====================================================================
#ifdef FSH

#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

#if defined RAINBOW && defined OVERWORLD
#include "/lib/noise.glsl"
#include "/lib/weather.glsl"
#endif

#ifdef END
#include "/lib/noise.glsl"
#include "/lib/end_sky.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;

#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
uniform sampler2D colortex5; // smoothed clouds (half resolution)

float getViewZ(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.z / p.w;
}

// Upscale the clouds from half resolution. Weighted by depth
// so no clouds "bleed" over mountain edges.
vec4 getUpsampledClouds(float depth) {
    vec2 halfRes = vec2(viewWidth, viewHeight) * 0.5;
    vec2 pos  = texcoord * halfRes - 0.5;
    vec2 base = floor(pos);
    vec2 f    = pos - base;
    float z0  = getViewZ(texcoord, depth);

    vec4 sum = vec4(0.0);
    float weightSum = 0.0;
    vec4 bilinear = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2(float(i == 1 || i == 3), float(i >= 2));
        vec2 uv = clamp((base + o + 0.5) / halfRes, vec2(0.0), vec2(1.0) - 0.5 / halfRes);
        vec4 c = texture2D(colortex5, uv * 0.5);
        float w = mix(1.0 - f.x, f.x, o.x) * mix(1.0 - f.y, f.y, o.y);
        bilinear += c * w;

        float zi = getViewZ(uv, texture2D(depthtex0, uv).r);
        w *= exp(-abs(zi - z0) / (abs(z0) * 0.03 + 0.1));
        sum += c * w;
        weightSum += w;
    }
    return weightSum > 1e-4 ? sum / weightSum : bilinear;
}
#endif

/* DRAWBUFFERS:0 */
void main() {
    vec4 color = texture2D(colortex0, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;

    if (depth >= 1.0) {
        #if defined NETHER
        vec3 sky = getFogColor(vec3(0.0, 0.0, -1.0));
        #elif defined END
        vec4 viewPos = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
        vec3 worldDir = mat3(gbufferModelViewInverse) * normalize(viewPos.xyz / viewPos.w);
        float pxAngle = 2.0 / (gbufferProjection[1][1] * viewHeight);
        vec3 sky = getEndSky(worldDir, pxAngle);
        #else
        vec4 viewPos = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
        vec3 viewDir = normalize(viewPos.xyz / viewPos.w);

        vec3 sky = getSkyColor(viewDir, sunVec, upVec);

        #ifdef SHADER_STARS
        // Custom stars: at night, not during rain, fainter at the horizon
        float starFade = (1.0 - sunVisibility) * (1.0 - sunVisibility) * (1.0 - rainStrength)
                       * smoothstep(-0.05, 0.25, dot(viewDir, upVec)) * STAR_BRIGHTNESS;
        if (starFade > 0.001) {
            float pxAngle = 2.0 / (gbufferProjection[1][1] * viewHeight);
            sky += getStars(mat3(gbufferModelViewInverse) * viewDir, pxAngle) * starFade;
        }
        #endif

        // Vanilla stars (and vanilla sun/moon if the round sun is off)
        vec3 skyObjects = texture2D(colortex1, texcoord).rgb;
        sky += toLinear(skyObjects) * (2.5 * max(STAR_BRIGHTNESS, 1.0));

        #ifdef RAINBOW
        sky += getRainbow(viewDir, sunVec, upVec);
        #endif

        // Sun and moon last: the moon disc covers the stars behind it
        #ifdef ROUND_SUN_MOON
        applySunMoon(sky, viewDir, sunVec, upVec, eastVec);
        #endif
        #endif

        if (isEyeInWater == 2) sky = vec3(1.0, 0.28, 0.03) * 1.5;
        if (isEyeInWater == 3) sky = vec3(0.55, 0.65, 0.80) * 0.6;
        sky *= (1.0 - blindness) * (1.0 - darknessFactor);

        color = vec4(sky, 1.0);
    }

    #if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
    if (depth >= 0.56) { // not over the hand
        vec4 clouds = getUpsampledClouds(depth);
        color.rgb = color.rgb * (1.0 - clouds.a) + clouds.rgb;
    }
    #endif

    gl_FragData[0] = color;
}

#endif
