/*
    Tabby Shaders - Shadows
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Cheap: distorted shadow map + hardware PCF (1 or 4 samples).
*/

float getDistortFactor(vec2 p) {
    return length(p) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
}

// Must be identical in the shadow pass and when sampling
vec3 distortShadow(vec3 p) {
    p.xy /= getDistortFactor(p.xy);
    p.z *= 0.2;
    return p;
}

// Vertex shader: position in shadow clip space, offset along the normal (against shadow acne)
vec3 getShadowClipPos(vec3 playerPos, vec3 worldNormal) {
    vec3 sView = (shadowModelView * vec4(playerPos, 1.0)).xyz;
    vec4 sClip = shadowProjection * vec4(sView, 1.0);

    float texelSize = 2.0 * shadowDistance / float(shadowMapResolution) * getDistortFactor(sClip.xy);
    sView += mat3(shadowModelView) * worldNormal * (texelSize * 1.5 + 0.01);

    return (shadowProjection * vec4(sView, 1.0)).xyz;
}

#ifdef FSH
// shadowtex1 = shadow depth WITHOUT translucent blocks (glass/water cast no hard shadows)
uniform sampler2DShadow shadowtex1;

// 1 = lit, 0 = in shadow
float sampleShadow(vec3 shadowClipPos) {
    vec3 p = distortShadow(shadowClipPos) * 0.5 + 0.5;
    p.z -= 0.00002;

    #if SHADOW_FILTER == 1
    float t = 1.0 / float(shadowMapResolution);
    float s = shadow2D(shadowtex1, p + vec3( t,        0.5 * t, 0.0)).x
            + shadow2D(shadowtex1, p + vec3(-t,       -0.5 * t, 0.0)).x
            + shadow2D(shadowtex1, p + vec3( 0.5 * t, -t,       0.0)).x
            + shadow2D(shadowtex1, p + vec3(-0.5 * t,  t,       0.0)).x;
    return s * 0.25;
    #else
    return shadow2D(shadowtex1, p).x;
    #endif
}
#endif
