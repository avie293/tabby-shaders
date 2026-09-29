/*
    Tabby Shaders - BSL-style fog
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    The fog color is the sky color in the view direction -> terrain blends into the sky,
    towards the sunset the fog turns orange.
    Requires: common.glsl, sky.glsl
*/

float getEyeSkyLight() {
    return float(eyeBrightnessSmooth.y) / 240.0;
}

// Atmospheric haze (without the render distance border) - also used for clouds
float getAtmosphericFog(float dist, float worldY) {
    float density = FOG_DENSITY;
    density *= mix(1.6, 1.0, sunVisibility);             // a bit more haze at night
    density *= 1.0 + twilight * twilight * 0.8;          // golden haze at sunrise/sunset
    density *= 1.0 + rainStrength * 2.5 * RAIN_FOG;      // rain

    float d = dist * density / 256.0;
    float fog = 1.0 - exp(-0.8 * pow(d, 1.35));

    #ifdef FOG_ALTITUDE
    // Less haze at altitude (mountains look clearer)
    fog *= exp2(-max(worldY - 70.0, 0.0) / 64.0);
    #endif

    return fog;
}

// Soft fog at the edge of the render distance (hides chunk borders)
float getBorderFog(float dist) {
    float border = clamp((dist / far - FOG_START) / (1.0 - FOG_START), 0.0, 1.0);
    return border * border * (3.0 - 2.0 * border);
}

vec3 getFogColor(vec3 viewDir) {
#if defined NETHER
    return toLinear(fogColor) * 0.6;
#elif defined END
    return getEndSkyBase(mat3(gbufferModelViewInverse) * viewDir);
#else
    vec3 col = getSkyColor(viewDir, normalize(sunPosition), normalize(upPosition));
    #ifdef CAVE_FOG
    // Dark fog in caves instead of the bright sky color
    float eyeSky = getEyeSkyLight();
    col = mix(vec3(0.010, 0.010, 0.014) * (1.0 + MIN_LIGHT), col, eyeSky * eyeSky);
    #endif
    return col;
#endif
}

void applyFog(inout vec3 color, vec3 viewPos, vec3 playerPos) {
    float dist = max(length(viewPos), 1e-4);

    if (isEyeInWater == 1) {
        // Underwater
        float light = (0.08 + 0.92 * sunVisibility) * (0.25 + 0.75 * getEyeSkyLight());
        vec3 waterFog = vec3(0.03, 0.16, 0.22) * light;
        color = mix(color, waterFog, 1.0 - exp(-dist * 0.07));
    } else if (isEyeInWater == 2) {
        // In lava
        color = mix(color, vec3(1.0, 0.28, 0.03) * 1.5, 1.0 - exp(-dist * 1.2));
    } else if (isEyeInWater == 3) {
        // In powder snow
        color = mix(color, vec3(0.55, 0.65, 0.80) * 0.6, 1.0 - exp(-dist * 0.9));
    } else {
        vec3 fogCol = getFogColor(viewPos / dist);

        #if defined NETHER
        float fog = 1.0 - exp(-dist * 0.012 * FOG_DENSITY);
        #ifdef NETHER_LAVA_GLOW
        // Glowing haze above the lava ocean (y ~ 31): denser and orange
        float lavaHaze = exp(-max(playerPos.y + cameraPosition.y - 31.0, 0.0) / 14.0);
        fog = 1.0 - (1.0 - fog) * exp(-dist * 0.02 * lavaHaze);
        fogCol = mix(fogCol, LAVA_GLOW_COL * 0.9, lavaHaze * 0.65);
        #endif
        #elif defined END
        // Violet haze, much denser below the island (towards the void)
        float voidHaze = 1.0 + 2.0 * smoothstep(55.0, 0.0, playerPos.y + cameraPosition.y);
        float fog = 1.0 - exp(-dist * 0.014 * FOG_DENSITY * voidHaze);
        #else
        float fog = getAtmosphericFog(dist, playerPos.y + cameraPosition.y);
        #endif

        float border = getBorderFog(dist);
        fog = 1.0 - (1.0 - fog) * (1.0 - border);

        color = mix(color, fogCol, fog);
    }

    // Blindness & darkness (warden)
    color *= 1.0 - blindness * clamp((dist - 1.5) / 4.0, 0.0, 1.0);
    color *= 1.0 - darknessFactor * clamp((dist - 3.0) / 12.0, 0.0, 1.0);
}
