/*
    Tabby Shaders - Colors of the light sources (shared by colored lighting and hand light)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    type = block/item ID - 10099  (10101 -> 2 ... 10114 -> 15), see block.properties/item.properties
    Strength roughly matches the vanilla light level.
*/

vec3 getEmitterColor(int type) {
    if (type ==  2) return vec3(1.00, 0.55, 0.22) * 0.93; // torch, lantern, campfire, fire, jack o'lantern, furnace
    if (type ==  3) return vec3(0.15, 0.70, 1.00) * 0.67; // soul torch, soul lantern, soul fire
    if (type ==  4) return vec3(1.00, 0.12, 0.04) * 0.60; // redstone torch, redstone ore
    if (type ==  5) return vec3(1.00, 0.72, 0.38) * 1.00; // glowstone, redstone lamp, shroomlight, copper bulb, ochre froglight
    if (type ==  6) return vec3(0.62, 0.88, 1.00) * 1.00; // sea lantern, beacon, end rod, conduit
    if (type ==  7) return vec3(1.00, 0.35, 0.08) * 1.00; // lava, magma block
    if (type ==  8) return vec3(0.62, 0.22, 1.00) * 0.67; // amethyst, crying obsidian, respawn anchor
    if (type ==  9) return vec3(0.40, 1.00, 0.30) * 0.93; // copper torch, copper lantern
    if (type == 10) return vec3(0.55, 1.00, 0.45) * 1.00; // verdant froglight
    if (type == 11) return vec3(1.00, 0.50, 0.90) * 1.00; // pearlescent froglight
    if (type == 12) return vec3(0.95, 0.80, 0.45) * 0.80; // glow lichen, glow berries
    if (type == 13) return vec3(0.50, 1.00, 0.65) * 0.60; // sea pickle
    if (type == 14) return vec3(1.00, 0.45, 0.15) * 0.60; // creaking heart
    return vec3(1.00, 0.60, 0.30) * 0.40;                 // 15: candles
}

// Glowing ores (type 40..48): faint light in their color
vec3 getOreColor(int type) {
    if (type == 40) return vec3(0.30, 0.90, 1.00); // diamond
    if (type == 41) return vec3(0.20, 1.00, 0.40); // emerald
    if (type == 42) return vec3(0.20, 0.35, 1.00); // lapis lazuli
    if (type == 43) return vec3(1.00, 0.10, 0.05); // Redstone
    if (type == 44) return vec3(1.00, 0.80, 0.20); // Gold
    if (type == 45) return vec3(1.00, 0.72, 0.55); // iron
    if (type == 46) return vec3(1.00, 0.55, 0.30); // copper
    if (type == 47) return vec3(1.00, 0.90, 0.85); // nether quartz
    return vec3(1.00, 0.80, 0.20);                 // 48: nether gold
}
