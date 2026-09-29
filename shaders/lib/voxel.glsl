/*
    Tabby Shaders - Voxel volume for colored lighting
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    128 x 64 x 128 blocks around the player, aligned to block borders.
    Images (shaders.properties): voxelImg (block types), floodImgA/B (light color, alternating)
*/

const ivec3 VOXEL_SIZE = ivec3(128, 64, 128);

// Position relative to the player -> voxel coordinate (in blocks, 0 .. VOXEL_SIZE)
vec3 playerToVoxel(vec3 playerPos) {
    return playerPos + fract(cameraPosition) + vec3(VOXEL_SIZE / 2);
}

#ifdef FSH
uniform sampler3D floodSamplerA;
uniform sampler3D floodSamplerB;

// rgb = hue of the block light (brightest channel = 1), a = amount (0 = no color info)
// oreLight = light from nearby glowing ores (0..0.5)
vec4 getColoredLight(vec3 playerPos, vec3 worldNormal, out float oreLight) {
    oreLight = 0.0;

    // Sample in front of the face (the block itself is solid and therefore dark)
    vec3 p = playerToVoxel(playerPos + worldNormal * 0.5);
    if (any(lessThan(p, vec3(0.5))) || any(greaterThan(p, vec3(VOXEL_SIZE) - 0.5))) return vec4(0.0);

    vec3 uv = p / vec3(VOXEL_SIZE);
    // On even frames the compute shader writes to B, on odd frames to A
    vec4 flood = mod(float(frameCounter), 2.0) < 0.5 ? texture3D(floodSamplerB, uv)
                                                     : texture3D(floodSamplerA, uv);
    vec3 light = flood.rgb;
    oreLight = flood.a;

    float peak = max(light.r, max(light.g, light.b));
    if (peak < 0.002) return vec4(0.0);

    vec3 hue = light / peak;
    hue = max(mix(vec3(luminance(hue)), hue, COLORED_LIGHTING_SATURATION), 0.0);
    return vec4(hue, clamp(peak * 6.0, 0.0, 1.0));
}
#endif
