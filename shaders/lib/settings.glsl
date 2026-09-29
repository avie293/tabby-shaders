/*
    Tabby Shaders - Settings
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Everything with a value list in [square brackets] appears in the Iris shader menu.
*/

// ===== Lighting =====
#define SUN_BRIGHTNESS 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.75 2.00]
#define AMBIENT_BRIGHTNESS 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.75 2.00]
#define BLOCKLIGHT_BRIGHTNESS 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.75 2.00]
#define NIGHT_BRIGHTNESS 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define MIN_LIGHT 0.40 // [0.00 0.10 0.20 0.30 0.40 0.50 0.75 1.00 1.50 2.00]
#define DYNAMIC_HANDLIGHT
#define HANDLIGHT_RANGE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define EMISSIVE_BLOCKS
#define EMISSIVE_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define GLOWING_ORES
#define ORE_GLOW_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00]

// ===== Materials =====
//#define PBR
#define PBR_NORMAL_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define FANCY_PORTALS
#define PORTAL_BRIGHTNESS 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
const float ambientOcclusionLevel = 1.00; // [0.00 0.25 0.50 0.75 1.00]

// ===== Colored lighting =====
#define COLORED_LIGHTING
#define COLORED_LIGHTING_SATURATION 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50]
#define COLORED_LIGHTING_RANGE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]

// Only with Iris support for compute shaders and custom images (otherwise normal torch light)
#if defined COLORED_LIGHTING && defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_COMPUTE_SHADERS
    #define USE_COLORED_LIGHTING
#endif

// ===== Light shafts =====
#define LIGHT_SHAFTS
#define LIGHT_SHAFT_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define LIGHT_SHAFT_SAMPLES 8 // [4 6 8 12 16]

// ===== Shadows =====
#define SHADOWS
#define SHADOW_FILTER 1 // [0 1]
const int shadowMapResolution = 1024; // [512 1024 1536 2048 3072 4096]
const float shadowDistance = 96.0; // [48.0 64.0 80.0 96.0 128.0 160.0 192.0 256.0]
const float shadowDistanceRenderMul = 1.0;
const bool shadowHardwareFiltering = true;
const float sunPathRotation = -35.0; // [-60.0 -50.0 -40.0 -35.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0]
#define SHADOW_DISTORT 0.85

// ===== Sky, sun & moon =====
#define ROUND_SUN_MOON
#define SUN_SIZE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define MOON_SIZE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define MOON_PHASE_LIGHT
#define SKY_BRIGHTNESS 1.00 // [0.50 0.75 1.00 1.25 1.50]
#define SHADER_STARS
#define STAR_BRIGHTNESS 1.00 // [0.00 0.50 1.00 1.50 2.00 3.00]

// ===== Fog =====
#define FOG_DENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define FOG_START 0.60 // [0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90]
#define FOG_ALTITUDE
#define CAVE_FOG
#define RAIN_FOG 1.00 // [0.00 0.50 1.00 1.50 2.00]

// ===== Weather =====
#define WET_SURFACES
#define PUDDLE_AMOUNT 0.50 // [0.00 0.25 0.50 0.75 1.00]
#define RAIN_RIPPLES
#define LIGHTNING_FLASH
#define RAINBOW
#define RAIN_OPACITY 0.60 // [0.20 0.30 0.40 0.50 0.60 0.70 0.80 1.00]
const float wetnessHalflife = 300.0;  // how fast the world gets wet (ticks)
const float drynessHalflife = 1200.0; // how slowly it dries again (ticks)

// ===== Nether & End =====
#define END_STORMS
#define NETHER_LAVA_GLOW

// ===== Clouds =====
//#define VOLUMETRIC_CLOUDS
#define VC_STYLE 0 // [0 1 2]
#define VC_AMOUNT 0.50 // [0.20 0.30 0.40 0.45 0.50 0.55 0.60 0.70 0.80]
#define VC_THICKNESS 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define VC_HEIGHT 0 // [0 128 160 192 224 256 320]
#define VC_QUALITY 16 // [8 12 16 24 32]
#define VC_SPEED 1.00 // [0.00 0.50 1.00 2.00 4.00]

// Vanilla clouds (when volumetric clouds are off)
#define CLOUD_FADE 0.85 // [0.00 0.25 0.50 0.60 0.70 0.80 0.85 0.90 0.95 1.00]
#define CLOUD_FADE_CURVE 1.00 // [0.50 0.75 1.00 1.50 2.00 3.00]
#define CLOUD_THICKNESS 4.0 // [2.0 3.0 4.0 5.0 6.0 8.0]
#define CLOUD_OPACITY 1.00 // [0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define CLOUD_DISTANCE 3.0 // [1.5 2.0 3.0 4.0 6.0 8.0]
#define CLOUD_HEIGHT_FALLBACK 192.0 // [128.0 160.0 192.0 224.0 256.0 320.0]

// ===== Water =====
#define WATER_COLOR_MODE 0 // [0 1]
#define WATER_TEXTURE 0.00 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define WATER_OPACITY 0.80 // [0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define WATER_DEPTH
#define WATER_DEPTH_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define WATER_WAVES
#define WATER_WAVE_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define WATER_WAVE_SPEED 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00]
#define WATER_REFLECTIONS
#define WATER_SSR
#define SSR_STEPS 16 // [8 12 16 24 32]
#define WATER_REFRACTION
#define WATER_REFRACTION_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00]

// ===== Waving =====
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVING_SPEED 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]

// ===== Post processing =====
#define EXPOSURE 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50]
#define SATURATION 1.10 // [0.80 0.90 1.00 1.05 1.10 1.15 1.20 1.30 1.40]
#define VIGNETTE
#define VIGNETTE_STRENGTH 0.30 // [0.10 0.20 0.30 0.40 0.50 0.60]

// ---------------------------------------------------------------------
// IMPORTANT: Iris only detects an on/off switch as a menu option if it is
// checked somewhere with a plain "#ifdef NAME" ("#if defined" does not count!).
// Without an option, shaders.properties treats the switch as "off".
#ifdef EMISSIVE_BLOCKS
#endif
#ifdef DYNAMIC_HANDLIGHT
#endif
#ifdef GLOWING_ORES
#endif
#ifdef PBR
#endif
#ifdef FANCY_PORTALS
#endif
#ifdef END_STORMS
#endif
#ifdef NETHER_LAVA_GLOW
#endif
#ifdef COLORED_LIGHTING
#endif
#ifdef SHADOWS
#endif
#ifdef LIGHT_SHAFTS
#endif
#ifdef ROUND_SUN_MOON
#endif
#ifdef MOON_PHASE_LIGHT
#endif
#ifdef FOG_ALTITUDE
#endif
#ifdef CAVE_FOG
#endif
#ifdef WATER_DEPTH
#endif
#ifdef WATER_WAVES
#endif
#ifdef WATER_REFLECTIONS
#endif
#ifdef WATER_SSR
#endif
#ifdef WATER_REFRACTION
#endif
#ifdef WAVING_PLANTS
#endif
#ifdef WAVING_LEAVES
#endif
#ifdef VIGNETTE
#endif
#ifdef VOLUMETRIC_CLOUDS
#endif
#ifdef WET_SURFACES
#endif
#ifdef RAIN_RIPPLES
#endif
#ifdef LIGHTNING_FLASH
#endif
#ifdef RAINBOW
#endif
#ifdef SHADER_STARS
#endif
