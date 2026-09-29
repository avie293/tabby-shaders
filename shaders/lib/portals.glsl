/*
    Tabby Shaders - 3D portals (parallax: layers "behind" the surface)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Nether portal: vanilla texture on top, several layers of swirling portal energy below
    End portal:    star field made of several depth layers in teal, blue, green and violet
    Requires: common.glsl, noise.glsl, gtexture
*/

// Axes of a block face in world coordinates
void getFaceAxes(vec3 worldN, out vec3 T, out vec3 B) {
    if (abs(worldN.y) > 0.5) {
        T = vec3(1.0, 0.0, 0.0);
        B = vec3(0.0, 0.0, 1.0);
    } else {
        T = normalize(cross(vec3(0.0, 1.0, 0.0), worldN));
        B = vec3(0.0, 1.0, 0.0);
    }
}

// Swirled noise (domain warping) - looks like flowing energy
float portalSwirl(vec2 p, float t) {
    vec2 q = vec2(noiseSmooth(p + vec2(t * 0.35, 0.0)),
                  noiseSmooth(p + vec2(5.2, 1.3) - vec2(0.0, t * 0.30)));
    return noiseSmooth(p * 1.6 + q * 3.0 + vec2(0.0, t * 0.2));
}

vec3 getNetherPortal(vec3 surfaceCol, vec3 playerPos, vec3 worldN) {
    vec3 T, B;
    getFaceAxes(worldN, T, B);

    vec3 worldPos = playerPos + cameraPosition;
    vec3 V = normalize(playerPos);
    float NdotV = max(abs(dot(worldN, V)), 0.1);
    vec2 base = vec2(dot(worldPos, T), dot(worldPos, B));
    vec2 dir  = vec2(dot(V, T), dot(V, B)) / NdotV; // moves behind the surface with depth
    float t = frameTimeCounter;

    vec3 col = surfaceCol * 0.8; // vanilla texture as the top layer
    for (int i = 1; i <= 5; i++) {
        float fi = float(i);
        vec2 p = (base + dir * (fi * 0.18)) * (1.4 + fi * 0.25);
        float n = portalSwirl(p + fi * 13.7, t * (0.6 + fi * 0.15));
        float streak = n * n * n; // only the bright swirls, deep violet in between
        vec3 layer = mix(vec3(0.05, 0.00, 0.16), vec3(0.95, 0.45, 1.00), streak) * (0.25 + streak);
        col += layer * (0.9 / (1.0 + fi * 0.8)); // deeper layers are darker
    }
    return col * PORTAL_BRIGHTNESS;
}

vec3 endPortalLayerColor(int i) {
    if (i == 0) return vec3(0.20, 0.85, 0.75);
    if (i == 1) return vec3(0.15, 0.55, 0.95);
    if (i == 2) return vec3(0.45, 0.25, 0.95);
    if (i == 3) return vec3(0.20, 0.95, 0.55);
    if (i == 4) return vec3(0.10, 0.70, 0.90);
    if (i == 5) return vec3(0.60, 0.30, 0.90);
    if (i == 6) return vec3(0.25, 0.90, 0.80);
    return vec3(0.30, 0.50, 1.00);
}

// gtexture is the star texture end_portal.png here (tileable)
vec3 getEndPortal(vec3 playerPos, vec3 worldN) {
    vec3 T, B;
    getFaceAxes(worldN, T, B);

    vec3 worldPos = playerPos + cameraPosition;
    vec3 V = normalize(playerPos);
    float NdotV = max(abs(dot(worldN, V)), 0.08);
    vec2 base = vec2(dot(worldPos, T), dot(worldPos, B));
    vec2 dir  = vec2(dot(V, T), dot(V, B)) / NdotV;
    float t = frameTimeCounter;

    vec3 col = vec3(0.003, 0.006, 0.012); // deep space
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        vec2 p = base + dir * (0.3 + fi * 0.5); // every layer lies deeper
        float angle = fi * 1.3;
        vec2 uv = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * p * (0.25 + fi * 0.04)
                + vec2(t * 0.004 * (fi + 1.0), t * 0.002);
        vec3 stars = toLinear(texture2D(gtexture, uv).rgb);
        col += stars * endPortalLayerColor(i) * (1.3 / (1.0 + fi * 0.5)); // deeper layers are darker
    }

    // Faint nebula in the depth
    float nebula = noiseSmooth((base + dir * 2.0) * 0.8 + vec2(t * 0.05, 0.0));
    col += vec3(0.02, 0.12, 0.14) * (nebula * nebula * nebula);

    return col * PORTAL_BRIGHTNESS;
}
