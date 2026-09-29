/*
    Tabby Shaders - PBR (labPBR 1.3)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Only works with a PBR resource pack. Without one, Iris binds neutral textures
    (flat normals, no smoothness, no emission) -> nothing changes then.

    normals:  RG = normal in tangent space, B = material AO, A = height
    specular: R = smoothness, G = F0 (230/255 and up = metal), B = porosity/SSS, A = emission (255 = off)
*/

uniform sampler2D normals;
uniform sampler2D specular;

// Normal with normal map (view space). N = face normal, tangent.w = bitangent direction
vec3 getPBRNormal(vec3 N, vec4 tangent, vec2 uv, out float ao) {
    vec4 nTex = texture2D(normals, uv);
    ao = nTex.b;

    // Some geometry has no tangent -> keep the face normal
    float tLen = length(tangent.xyz);
    if (tLen < 0.5) return N;

    vec2 xy = (nTex.rg * 2.0 - 1.0) * PBR_NORMAL_STRENGTH;
    vec3 nTS = vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));

    vec3 T = normalize(tangent.xyz / tLen - N * dot(N, tangent.xyz / tLen));
    vec3 B = cross(T, N) * (tangent.w < 0.0 ? -1.0 : 1.0);
    return normalize(T * nTS.x + B * nTS.y + N * nTS.z);
}

void getPBRMaterial(vec2 uv, out float smoothness, out float f0, out bool metal, out float emission) {
    vec4 s = texture2D(specular, uv);
    smoothness = s.r;
    metal      = s.g >= 229.5 / 255.0;
    f0         = metal ? 1.0 : max(s.g, 0.02);
    emission   = s.a < 0.999 ? s.a : 0.0;
}

vec3 fresnelSchlick(vec3 F0, float cosTheta) {
    float f = 1.0 - clamp(cosTheta, 0.0, 1.0);
    float f2 = f * f;
    return F0 + (1.0 - F0) * (f2 * f2 * f);
}

// Specular highlight (GGX). V = view direction to the surface, L = direction to the light
vec3 getSpecularHighlight(vec3 N, vec3 V, vec3 L, float roughness, vec3 F0) {
    vec3 H = normalize(L - V);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(-V, H), 0.0);

    float a  = max(roughness * roughness, 0.002);
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    float D  = a2 / (3.14159 * d * d);

    vec3 spec = D * fresnelSchlick(F0, VdotH) * NdotL / (4.0 * max(VdotH * VdotH, 0.1));
    return min(spec, vec3(30.0));
}
