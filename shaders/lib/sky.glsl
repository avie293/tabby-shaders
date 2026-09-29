/*
    Tabby Shaders - Sky, sun and moon
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    getSkyColor() is used for the sky AND as the fog color.
*/

const vec3 SKY_DAY_ZENITH    = vec3(0.10, 0.24, 0.78);
const vec3 SKY_DAY_HORIZON   = vec3(0.50, 0.66, 1.00);
const vec3 SKY_TWI_ZENITH    = vec3(0.12, 0.16, 0.42);
const vec3 SKY_TWI_HORIZON   = vec3(0.62, 0.44, 0.52);
const vec3 SKY_TWI_SUN       = vec3(1.00, 0.42, 0.12);
const vec3 SKY_NIGHT_ZENITH  = vec3(0.004, 0.007, 0.018);
const vec3 SKY_NIGHT_HORIZON = vec3(0.018, 0.026, 0.050);
const vec3 SKY_RAIN          = vec3(0.30, 0.33, 0.38);

// viewDir, sunVec and upVec must be normalized and in view space
vec3 getSkyColor(vec3 viewDir, vec3 sunVec, vec3 upVec) {
    float VoU = dot(viewDir, upVec);
    float VoS = dot(viewDir, sunVec);
    float g = sqrt(clamp(VoU, 0.0, 1.0)); // 0 = horizon, 1 = zenith

    vec3 day   = mix(SKY_DAY_HORIZON, SKY_DAY_ZENITH, g);
    vec3 night = mix(SKY_NIGHT_HORIZON, SKY_NIGHT_ZENITH, g);

    // Twilight: warm towards the sun, purple on the opposite side
    float sunSide = VoS * 0.5 + 0.5;
    vec3 twiHorizon = mix(SKY_TWI_HORIZON, SKY_TWI_SUN, sunSide * sunSide * sunSide);
    vec3 twi = mix(twiHorizon, SKY_TWI_ZENITH, g);

    float tw  = twilight * twilight;
    vec3 lit  = mix(day, twi, tw);
    float amount = clamp(sunVisibility + tw * 0.5 * sunSide, 0.0, 1.0);
    vec3 sky  = mix(night, lit, amount);

    // Glow around the sun
    float VoSp = max(VoS, 0.0);
    float glow = pow(VoSp, 10.0) * 0.35 + pow(VoSp, 120.0) * 0.8;
    vec3 glowCol = mix(SKY_TWI_SUN, vec3(1.0, 0.88, 0.72), timeBrightness);
    sky += glowCol * glow * sunVisibility * (1.0 + tw);

    // Faint glow around the moon
    float moonGlow = pow(max(-VoS, 0.0), 24.0) * 0.04;
    sky += MOON_COL * moonGlow * moonVisibility;

    // A bit darker below the horizon
    sky *= mix(1.0, 0.6, clamp(-VoU * 2.5, 0.0, 1.0));

    // rain
    vec3 rainSky = SKY_RAIN * mix(0.02, 1.0, sunVisibility) * mix(1.0, 0.8, g);
    sky = mix(sky, rainSky, rainStrength);

    // Thunder: darker, menacing sky; lightning brightens it briefly
    sky *= 1.0 - thunderStrength * 0.4;
    sky += LIGHTNING_COL * (getLightningFlash() * 0.5);

    return sky * SKY_BRIGHTNESS;
}

// Cheap noise for the moon surface (only evaluated inside the moon disc)
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ---------------------------------------------------------------------
//  Shader stars: sharp points of light, twinkling, rotating with the sky
// ---------------------------------------------------------------------
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// worldDir = view direction in world space, pxAngle = angular size of one pixel
vec3 getStars(vec3 worldDir, float pxAngle) {
    // Rotate into the celestial frame (like the sun path) so the stars move over time
    float a = sunAngle * 6.2831853;
    float r = radians(sunPathRotation);
    vec3 d = vec3(worldDir.z, worldDir.y, -worldDir.x);
    d = vec3(d.x * cos(r) + d.y * sin(r), -d.x * sin(r) + d.y * cos(r), d.z);
    d = vec3(d.x, d.y * cos(a) + d.z * sin(a), -d.y * sin(a) + d.z * cos(a));

    // Split the sky into small cells, a few cells contain a star
    const float scale = 220.0;
    vec3 p = d * scale;
    vec3 cell = floor(p);
    float h = hash13(cell);
    if (h < 0.991) return vec3(0.0);

    vec3 center = cell + 0.2 + 0.6 * vec3(hash13(cell + 11.1), hash13(cell + 23.7), hash13(cell + 37.3));
    vec3 toStar = p - center;
    float dist = length(toStar - d * dot(toStar, d)); // distance perpendicular to the view ray

    // Always about 1-2 pixels big, regardless of resolution or field of view
    float radius = max(pxAngle * scale * 0.7, 0.04);
    float star = exp(-dist * dist / (radius * radius));

    // Few bright, many faint stars; slight twinkling; bluish to yellowish
    float b = hash13(cell + 5.3);
    float brightness = mix(0.15, 4.0, b * b * b * b);
    float twinkle = 0.7 + 0.3 * sin(frameTimeCounter * (1.5 + b * 3.0) + h * 400.0);
    vec3 col = mix(vec3(0.70, 0.80, 1.00), vec3(1.00, 0.88, 0.72), hash13(cell + 71.9));

    return col * (star * brightness * twinkle);
}

// ---------------------------------------------------------------------
//  Moon surface (only evaluated inside the moon disc -> practically free)
// ---------------------------------------------------------------------

// Crater in a cell: dark floor, bright rim. Returns: brightness change
float moonCrater(vec2 p, float seed, float chance) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float h = hash12(cell + seed);
    if (h > chance) return 0.0; // not every cell has a crater

    vec2 center = 0.3 + 0.4 * vec2(fract(h * 7.31), hash12(cell + seed + 7.3));
    float radius = 0.12 + 0.2 * hash12(cell + seed + 3.1);
    float d = length(f - center) / radius;

    float floorDark = -0.22 * (1.0 - smoothstep(0.55, 1.0, d));
    float rimLight  =  0.16 * exp(-(d - 1.0) * (d - 1.0) * 30.0);
    return floorDark + rimLight;
}

// Brightness of the moon surface at a point on the sphere (n = sphere normal)
float moonAlbedo(vec3 n) {
    // Longitude/latitude -> details get compressed towards the rim like on a real sphere
    vec2 sph = vec2(atan(n.x, n.z), asin(clamp(n.y, -1.0, 1.0)));

    // Dark "seas" (maria)
    float maria = valueNoise(sph * 2.2 + 3.0) * 0.65 + valueNoise(sph * 5.0 + 11.0) * 0.35;
    float albedo = mix(1.0, 0.5, smoothstep(0.42, 0.62, maria));

    // Large and small craters, fine grain
    albedo += moonCrater(sph * 4.0, 0.0, 0.45) + moonCrater(sph * 10.0, 17.0, 0.22) * 0.45;
    albedo *= 0.88 + 0.12 * valueNoise(sph * 28.0);

    return clamp(albedo, 0.2, 1.1);
}

// ---------------------------------------------------------------------
//  Round sun and round moon
//  eastVec = world axis +X in view space (direction of the celestial path)
// ---------------------------------------------------------------------
void applySunMoon(inout vec3 sky, vec3 viewDir, vec3 sunVec, vec3 upVec, vec3 eastVec) {
    float horizonFade = smoothstep(-0.03, 0.02, dot(viewDir, upVec));
    float weather = 1.0 - rainStrength;
    float visible = horizonFade * weather;
    if (visible < 0.001) return;

    // --- Sun ---
    float sunRadius = 0.05 * SUN_SIZE;
    float VoS = dot(viewDir, sunVec);
    if (VoS > 1.0 - 8.0 * sunRadius * sunRadius) {
        float x = sqrt(2.0 * max(1.0 - VoS, 0.0)) / sunRadius; // 0 = center, 1 = rim

        vec3 sunCol = mix(vec3(1.0, 0.30, 0.05), vec3(1.0, 0.93, 0.82), timeBrightness);

        // Disc with limb darkening (rim darker and redder, like the real sun)
        float mu = sqrt(max(1.0 - x * x, 0.0));
        vec3 limb = mix(vec3(1.0, 0.75, 0.55), vec3(1.0), mu) * (0.45 + 0.55 * mu);
        float disc = 1.0 - smoothstep(0.94, 1.0, x);
        // Darker at the horizon so the disc stays deep orange after tonemapping
        vec3 sunDisc = sunCol * limb * mix(1.6, 35.0, timeBrightness * timeBrightness);

        // Soft corona right around the disc
        float corona = (exp(-max(x - 1.0, 0.0) * 3.0) * 0.5 + exp(-x * 0.6) * 0.12) * mix(0.6, 1.0, timeBrightness);
        sky += sunCol * (corona * (1.0 - disc) * visible);

        // The disc covers the sky behind it (otherwise it looks washed out)
        sky = mix(sky, sunDisc, disc * visible);
    }

    // --- Moon (always opposite the sun in Minecraft) ---
    vec3 moonVec = -sunVec;
    float moonRadius = 0.05 * MOON_SIZE;
    float VoM = dot(viewDir, moonVec);
    if (VoM > 1.0 - 8.0 * moonRadius * moonRadius) {
        // Local axes on the moon disc (aligned with the celestial path)
        vec3 tangent = eastVec - dot(eastVec, moonVec) * moonVec;
        float tLen = length(tangent);
        tangent = tLen > 1e-4 ? tangent / tLen : upVec;
        vec3 bitangent = cross(moonVec, tangent);

        vec2 uv = vec2(dot(viewDir, tangent), dot(viewDir, bitangent)) / moonRadius;
        float d = length(uv);

        // Soft glow around the moon
        float halo = exp(-max(d - 1.0, 0.0) * 4.0) * 0.035 + exp(-d * 0.8) * 0.01;
        sky += MOON_COL * halo * visible;

        if (d < 1.0) {
            vec3 n = vec3(uv, sqrt(1.0 - d * d)); // sphere normal

            // Moon phase: 0 = full moon, 4 = new moon. Soft terminator instead of a hard edge
            float phase = float(moonPhase) * 0.785398; // 2*PI / 8
            vec3 phaseLight = vec3(sin(phase), 0.0, cos(phase));
            float NdotL = dot(n, phaseLight);
            float lit = smoothstep(-0.04, 0.22, NdotL) * (0.85 + 0.15 * max(NdotL, 0.0));

            float albedo = moonAlbedo(n);
            vec3 moonLit    = vec3(0.92, 0.94, 1.00) * (albedo * lit * 0.85);
            vec3 earthshine = vec3(0.35, 0.45, 0.70) * (albedo * 0.012);

            // The disc covers sky and stars; some air lies in front of it
            float mask = (1.0 - smoothstep(0.96, 1.0, d)) * visible;
            sky = mix(sky, sky * 0.35 + moonLit + earthshine, mask);
        }
    }
}

// ---------------------------------------------------------------------
//  End: base sky color (also used for the fog)
// ---------------------------------------------------------------------
const vec3 END_ZENITH  = vec3(0.006, 0.003, 0.016);
const vec3 END_HORIZON = vec3(0.060, 0.022, 0.095);

vec3 getEndSkyBase(vec3 worldDir) {
    vec3 col = mix(END_HORIZON, END_ZENITH, smoothstep(-0.3, 0.7, worldDir.y));
    return col * (1.0 + getEndSkyFlash() * 2.0);
}
