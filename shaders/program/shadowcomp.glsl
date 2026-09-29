/*
    Tabby Shaders - Colored lighting: propagation (compute shader, runs after the shadow pass)
    Copyright (c) 2026 Avie29 - Licensed under CC BY-NC 4.0 (see LICENSE)
    Flood fill: every frame spreads the light one block further.
    Solid blocks stop light, light sources set their color.
    Colors mix (soul torch + redstone = purple).
*/

#include "/lib/settings.glsl"

#ifdef USE_COLORED_LIGHTING

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(16, 8, 16); // 128 x 64 x 128 Voxel

layout(r8ui) readonly uniform uimage3D voxelImg;
layout(rgba16f) uniform image3D floodImgA;
layout(rgba16f) uniform image3D floodImgB;

uniform int frameCounter;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

const ivec3 VOXEL_SIZE = ivec3(128, 64, 128);
const float LIGHT_FALLOFF = pow(0.86, 1.0 / COLORED_LIGHTING_RANGE);
const float ORE_FALLOFF   = 0.72; // ore light only reaches a few blocks

#include "/lib/light_colors.glsl"

// Block type 16..31 -> stained glass color (light gets tinted when passing through)
const vec3 GLASS_COLORS[16] = vec3[](
    vec3(1.00, 1.00, 1.00), // white
    vec3(1.00, 0.55, 0.15), // orange
    vec3(0.95, 0.30, 0.95), // magenta
    vec3(0.45, 0.70, 1.00), // light blue
    vec3(1.00, 0.95, 0.25), // yellow
    vec3(0.55, 1.00, 0.20), // lime
    vec3(1.00, 0.55, 0.70), // pink
    vec3(0.50, 0.50, 0.50), // gray
    vec3(0.75, 0.75, 0.75), // light gray
    vec3(0.20, 0.75, 0.80), // cyan
    vec3(0.60, 0.25, 0.95), // purple
    vec3(0.20, 0.30, 1.00), // blue
    vec3(0.65, 0.42, 0.25), // brown
    vec3(0.35, 0.60, 0.15), // green
    vec3(1.00, 0.12, 0.08), // red
    vec3(0.12, 0.12, 0.12)  // black
);

bool readA;

// rgb = light color, a = ore light
vec4 loadPrevious(ivec3 p) {
    if (any(lessThan(p, ivec3(0))) || any(greaterThanEqual(p, VOXEL_SIZE))) return vec4(0.0);
    vec4 v = readA ? imageLoad(floodImgA, p) : imageLoad(floodImgB, p);
    // Protection against uninitialized memory in the first frame
    if (any(isnan(v)) || any(isinf(v))) return vec4(0.0);
    return clamp(v, 0.0, 1.0);
}

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    readA = (frameCounter & 1) == 0; // even frames: read A, write B

    // The volume moves with the player -> shift old values by the movement
    ivec3 prev = pos + ivec3(floor(cameraPosition) - floor(previousCameraPosition));
    uint type = imageLoad(voxelImg, pos).r;

    vec4 light = vec4(0.0);
    if (type != 1u) {
        vec4 n = max(max(loadPrevious(prev + ivec3(1, 0, 0)), loadPrevious(prev - ivec3(1, 0, 0))),
                 max(max(loadPrevious(prev + ivec3(0, 1, 0)), loadPrevious(prev - ivec3(0, 1, 0))),
                     max(loadPrevious(prev + ivec3(0, 0, 1)), loadPrevious(prev - ivec3(0, 0, 1)))));
        light = n * vec4(vec3(LIGHT_FALLOFF), ORE_FALLOFF);

        if (type >= 40u) {
            #ifdef GLOWING_ORES
            // Ore: faint color + its own ore light in the alpha channel
            light = max(light, vec4(getOreColor(int(type)) * 0.35, 0.5));
            #else
            light = vec4(0.0); // without glowing ores: normal solid block
            #endif
        } else if (type >= 16u) {
            vec3 glass = GLASS_COLORS[type - 16u];
            light *= vec4(glass, dot(glass, vec3(0.2126, 0.7152, 0.0722)));
        } else if (type >= 2u) {
            light.rgb = max(light.rgb, getEmitterColor(int(type)));
        }
    }

    if (readA) imageStore(floodImgB, pos, light);
    else       imageStore(floodImgA, pos, light);
}

#else

// Colored lighting off: do nothing
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
void main() {}

#endif
