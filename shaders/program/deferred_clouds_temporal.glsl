/*
    Tabby Shaders - Volumetric clouds, step 2: temporal smoothing (deferred1, half resolution)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Blends the noisy raw image with the result of the previous frames:
      - Reprojection: where was this cloud point in the last frame?
      - Catmull-Rom sampling: the old image is not blurred when shifted
      - Neighborhood clamping: the old image may only provide values that occur in the 3x3
        neighborhood of the current image -> no smearing and no ghosting
      - Less smoothing during fast movement
    colortex4/6 = raw image/distance, colortex5 = smoothed result (kept for the next frame)
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

uniform sampler2D colortex4; // raw image
uniform sampler2D colortex5; // result of the last frame
uniform sampler2D colortex6; // cloud distance
uniform sampler2D depthtex0;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;

// Catmull-Rom (5 fetches) on the half resolution quarter. halfPos in half resolution pixels.
vec4 sampleHistory(vec2 halfPos, vec2 fullRes, vec2 halfRes) {
    halfPos = clamp(halfPos, vec2(1.5), halfRes - 2.5);

    vec2 texPos1 = floor(halfPos - 0.5) + 0.5;
    vec2 f = halfPos - texPos1;
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    vec2 w12 = w1 + w2;

    // Half resolution pixel i lies exactly on buffer pixel i -> divide by the full resolution
    vec2 p0  = (texPos1 - 1.0) / fullRes;
    vec2 p3  = (texPos1 + 2.0) / fullRes;
    vec2 p12 = (texPos1 + w2 / w12) / fullRes;

    vec4 result = texture2D(colortex5, vec2(p12.x, p0.y)) * (w12.x * w0.y)
                + texture2D(colortex5, vec2(p0.x, p12.y)) * (w0.x * w12.y)
                + texture2D(colortex5, p12)               * (w12.x * w12.y)
                + texture2D(colortex5, vec2(p3.x, p12.y)) * (w3.x * w12.y)
                + texture2D(colortex5, vec2(p12.x, p3.y)) * (w12.x * w3.y);
    float weight = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
    return result / weight;
}

/* DRAWBUFFERS:5 */
void main() {
    vec2 fullRes = vec2(viewWidth, viewHeight);
    vec2 halfRes = fullRes * 0.5;
    vec2 px = gl_FragCoord.xy; // half resolution pixel

    float depth = texture2D(depthtex0, texcoord).r;
    if (depth < 0.56) { // hand
        gl_FragData[0] = vec4(0.0);
        return;
    }

    vec4 current = texture2D(colortex4, px / fullRes);

    // Allowed value range for the old image: minimum/maximum of the 3x3 neighborhood
    vec4 nMin = current;
    vec4 nMax = current;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 q = clamp(px + vec2(float(x), float(y)), vec2(0.5), halfRes - 0.5);
            vec4 c = texture2D(colortex4, q / fullRes);
            nMin = min(nMin, c);
            nMax = max(nMax, c);
        }
    }

    // Where was this cloud point on screen in the last frame?
    float cloudDist = texture2D(colortex6, px / fullRes).r;
    vec4 viewPos = gbufferProjectionInverse * vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0);
    vec3 worldDir = mat3(gbufferModelViewInverse) * normalize(viewPos.xyz / viewPos.w);
    vec3 prevPlayerPos = worldDir * cloudDist + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
    vec4 prevClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevPlayerPos, 1.0));

    vec4 result = current;
    if (prevClip.w > 0.0) {
        vec2 prevUV = prevClip.xy / prevClip.w * 0.5 + 0.5;
        if (all(greaterThan(prevUV, vec2(0.0))) && all(lessThan(prevUV, vec2(1.0)))) {
            vec4 history = sampleHistory(prevUV * halfRes, fullRes, halfRes);

            // Discard garbage from the first frame (NaN/huge values)
            bool valid = !any(notEqual(history, history)) && !any(greaterThan(abs(history), vec4(1000.0)));
            if (valid) {
                history = clamp(history, nMin, nMax);

                // Standing still: smooth strongly. Fast movement: more of the current image
                float speed = length((texcoord - prevUV) * halfRes);
                float historyWeight = mix(0.75, 0.93, exp(-speed * 0.3));
                result = mix(current, history, historyWeight);
            }
        }
    }

    gl_FragData[0] = result;
}

#endif
