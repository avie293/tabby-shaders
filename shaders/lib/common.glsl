/*
    Tabby Shaders - shared uniforms, colors and time of day system
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Every uniform is declared only here to avoid duplicate declarations.
*/

// --- Custom uniforms (computed in shaders.properties, once per frame on the CPU) ---
uniform float sunVisibility;   // 0 = night, 1 = day
uniform float moonVisibility;  // 0 = day, 1 = night
uniform float timeBrightness;  // 0 = horizon, 1 = noon
uniform float twilight;        // 1 = sun at the horizon (sunrise/sunset)
uniform float shadowFade;      // fades sunlight out smoothly when sun and moon switch

// --- Iris Uniforms ---
uniform float sunAngle;         // 0 = sunrise, 0.25 = noon, 0.5 = sunset, 0.75 = midnight
uniform float rainStrength;
uniform float wetness;          // smoothed: rises during rain, drops slowly afterwards
uniform float thunderStrength;
uniform vec4 lightningBoltPosition; // w = 1 while a lightning bolt exists
uniform int biome_precipitation;    // 0 = no precipitation, 1 = rain, 2 = snow
uniform float endFlashIntensity;    // Minecraft end flashes (sky lights up briefly)
uniform float frameTimeCounter;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float blindness;
uniform float darknessFactor;
uniform float nightVision;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int frameCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

// --- Color palette (linear color space) ---
const vec3 SUN_COL_DAY    = vec3(1.00, 0.92, 0.80);
const vec3 SUN_COL_TWI    = vec3(1.00, 0.48, 0.18);
const vec3 MOON_COL       = vec3(0.45, 0.60, 1.00);
const vec3 AMB_COL_DAY    = vec3(0.55, 0.72, 1.00);
const vec3 AMB_COL_TWI    = vec3(0.72, 0.52, 0.52);
const vec3 AMB_COL_NIGHT  = vec3(0.30, 0.40, 0.70);
const vec3 BLOCKLIGHT_COL = vec3(1.00, 0.58, 0.28);
const vec3 NETHER_AMB_COL = vec3(1.00, 0.62, 0.45);
const vec3 END_AMB_COL    = vec3(0.60, 0.48, 0.80);
const vec3 END_LIGHT_COL  = vec3(0.70, 0.55, 0.95); // light "from the void" above
const vec3 END_FLASH_COL  = vec3(0.75, 0.55, 1.00);
const vec3 LAVA_GLOW_COL  = vec3(1.00, 0.38, 0.08);

// Schedule of the lightning bolts in the end storm (same for sky and terrain).
// Returns: brightness of this bolt (0 = none right now), boltDir = direction in the sky
float endStormHash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

float getEndBolt(int i, out vec3 boltDir) {
    float phase = frameTimeCounter * 0.45 + float(i) * 0.5;
    float seed = floor(phase) * 3.17 + float(i) * 11.3;
    float azimuth = endStormHash(seed + 1.7) * 6.2831853;
    boltDir = normalize(vec3(cos(azimuth), 0.05 + 0.25 * endStormHash(seed + 4.2), sin(azimuth)));
    if (endStormHash(seed) < 0.5) return 0.0;
    // Smoothly rising and fading glow instead of flickering
    float age = fract(phase);
    return smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.15, 0.9, age));
}

// How bright is the end sky flashing right now? (Minecraft flashes + storm lightning)
float getEndSkyFlash() {
    float flash = endFlashIntensity;
    #ifdef END_STORMS
    vec3 d;
    flash += (getEndBolt(0, d) + getEndBolt(1, d)) * 0.08; // only a soft shimmer on the island
    #endif
    return flash;
}

vec3 toLinear(vec3 c) {
    return pow(c, vec3(2.2));
}

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

const vec3 LIGHTNING_COL = vec3(0.55, 0.60, 0.85);

// Does it rain where the player stands? (not in deserts or snowy biomes)
float getBiomeRain() {
    return biome_precipitation == 1 ? 1.0 : 0.0;
}

// Lightning brightening with flicker
float getLightningFlash() {
#if defined LIGHTNING_FLASH && defined OVERWORLD
    return lightningBoltPosition.w * (0.65 + 0.35 * sin(frameTimeCounter * 41.0) * sin(frameTimeCounter * 17.0));
#else
    return 0.0;
#endif
}

// Moon phase: 1.0 = full moon, 0.0 = new moon
float getMoonFullness() {
    return abs(float(moonPhase) - 4.0) * 0.25;
}

// Color + strength of the direct light (sun or moon, whichever is up)
vec3 getDirectLightColor() {
#ifdef OVERWORLD
    vec3 sunCol = mix(SUN_COL_TWI, SUN_COL_DAY, timeBrightness) * (1.9 * SUN_BRIGHTNESS);

    float moonBright = 0.12 * NIGHT_BRIGHTNESS;
    #ifdef MOON_PHASE_LIGHT
    moonBright *= mix(0.35, 1.0, getMoonFullness());
    #endif
    vec3 moonCol = MOON_COL * moonBright;

    // shadowLightPosition points to the sun while it is above the horizon
    bool sunIsUp = dot(sunPosition, upPosition) > 0.0;
    vec3 col = sunIsUp ? sunCol : moonCol;

    return col * shadowFade * (1.0 - rainStrength * 0.8);
#elif defined END
    // No sunlight, but a pale light from the void above (casts shadows)
    return END_LIGHT_COL * (0.9 * SUN_BRIGHTNESS) * (1.0 + getEndSkyFlash() * 1.5);
#else
    return vec3(0.0);
#endif
}

// Ambient light (sky light)
vec3 getAmbientColor() {
#if defined NETHER
    return NETHER_AMB_COL * (0.42 * AMBIENT_BRIGHTNESS);
#elif defined END
    return (END_AMB_COL * 0.30 + END_FLASH_COL * (getEndSkyFlash() * 0.8)) * AMBIENT_BRIGHTNESS;
#else
    vec3 day   = mix(AMB_COL_TWI, AMB_COL_DAY, timeBrightness) * 0.55;
    vec3 night = AMB_COL_NIGHT * (0.06 * NIGHT_BRIGHTNESS);
    vec3 amb   = mix(night, day, sunVisibility);

    // Rain: greyer, a bit darker. Thunder: even darker, lightning brightens
    amb = mix(amb, vec3(luminance(amb)) * 0.85, rainStrength * 0.6);
    amb *= 1.0 - thunderStrength * 0.35;
    amb += LIGHTNING_COL * (getLightningFlash() * 1.2);
    return amb * AMBIENT_BRIGHTNESS;
#endif
}
