# Tabby Shaders

Copyright (c) 2026 Avie29 – licensed under [CC BY-NC 4.0](LICENSE) (attribution, non-commercial).

A fast Iris shaderpack for **Minecraft 26.x** in the style of BSL, built for high FPS.

## Features

- **BSL-style fog**: The fog takes on the sky color in the viewing direction. Distant terrain blends seamlessly into the sky and glows orange at sunset. There is also time-of-day haze, less fog at high altitude, dark cave fog, rain fog, and fog under water, in lava and in powder snow.
- **Sun & moon**: a round sun with a glow and a round moon with real **moon phases**. The light changes over the day: warm morning and evening light, white midday light, blue moonlight. How bright the moonlight is depends on the moon phase.
- **Vanilla clouds with an upward fade**: The shape stays vanilla. The clouds are opaque at the bottom and become transparent towards the top. Their color follows the time of day.
- **Volumetric clouds (optional)** in three styles: **Complementary Unbound** (realistic, tall cumulus clouds with cauliflower tops and silver linings), **BSL** (soft cumulus clouds) and **Complementary Reimagined** (blocky cloud fields on the vanilla grid). They are rendered at half resolution.
- **BSL-style water**: Terrain and sky are reflected (screen-space reflections), the ground is distorted by the waves, and the sun glitters on the water. Shallow water is clear, deep water is dark blue. The color is either the biome color or a uniform BSL blue. The vanilla texture can be blended in gradually (0% = pure shader water, 100% = vanilla).
- **Weather**: When it rains, the ground becomes wet and shiny, and reflective puddles with raindrop ripples form on flat surfaces. After the rain they dry slowly. Thunderstorms darken the sky, lightning briefly lights up the whole world, and a rainbow appears after the rain. All of this only happens in biomes where it actually rains.
- **Colored lighting**: Soul torches glow blue, redstone red, amethyst purple, copper torches green, froglights yellow, green or pink. The colors mix and are blocked by walls. The brightness still comes from the vanilla lightmap, so there are no light leaks. Optionally, stained glass tints the light passing through it. Requires Iris with compute shaders, otherwise normal torch light is used.
- **Glowing ores**: The colored spots of diamond, emerald, lapis, redstone, gold, iron, copper and the Nether ores glow and softly light up their surroundings in their color.
- **PBR (labPBR)**: With a PBR resource pack you get normal maps, specular highlights, metals, reflections and emissive spots. Off by default.
- **The End**: a custom sky with rotating storm clouds, lightning and a vortex at the zenith. Minecraft's End flashes light up everything. The island gets lighting with shadows and purple fog that matches the sky.
- **The Nether**: glowing lava haze above the lava ocean and orange lava light from below.
- **3D portals**: Nether and End portals get a depth effect, so you look into swirling energy or a star field.
- **Dynamic hand light**: Torches, lanterns and other glowing items in your hand light up the surroundings in their own color (soul torch blue, redstone torch red ...).
- **Light shafts**: sunbeams through trees and windows, especially nice at sunrise, sunset and under water.
- Cheap shadows (optional), waving plants and leaves, emissive blocks, ACES tonemapping.

## Performance

- Forward rendering: lighting is calculated directly while drawing, without expensive deferred lighting passes.
- Few fullscreen passes: `deferred` + `deferred1` for volumetric clouds (optional, half resolution, with temporal smoothing), `deferred2` for the sky, `composite` for water and light shafts, `final` for tonemapping.
- Colored lighting: one compute shader per frame on a 128×64×128 grid and one extra texture fetch per pixel in torch light. It needs the shadow pass, which therefore keeps running even with shadows turned off. Outside a 64-block safe zone the shadow pass is culled as usual.
- Shadows with hardware PCF (1 or 4 samples). The shadow pass only renders within the shadow distance. Translucent blocks (for colored glass light) and block entity shadows are separate options.
- Without shadows and colored lighting, the shadow pass is switched off completely.
- Profiles: **Potato** (no shadows, colored lighting, light shafts or water effects), **Low** (no shadows, colored lighting, light shafts or terrain reflections), **Medium** (default), **High**.

## Installation

1. Install [Iris](https://irisshaders.dev) for your 26.x version.
2. Copy the `tabby-shaders` folder (with the `shaders` subfolder) into `.minecraft/shaderpacks/`, or pack it as a ZIP.
3. Select it in-game under *Options → Video Settings → Shader Packs*.

## Structure

```text
shaders/
  shaders.properties     menu, profiles, time-of-day uniforms
  block.properties       block IDs (plants, leaves, water, light sources)
  lib/                   settings, sky, fog, lighting, shadows, wind
  program/               the actual shader code (once for all dimensions)
  *.vsh / *.fsh          Overworld (small wrappers -> program/)
  world-1/               Nether    (wrappers with #define NETHER)
  world1/                End       (wrappers with #define END)
```

All settings are in `shaders/lib/settings.glsl` and in the Iris menu.

Originally started from the Iris Example Shaderpack / XorDev's Default Shaderpack. License: see `LICENSE`. Exception: `shaders/lib/needs_iris.glsl` is covered by the license in the header of that file.
