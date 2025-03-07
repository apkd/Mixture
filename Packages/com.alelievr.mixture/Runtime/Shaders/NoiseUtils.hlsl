#ifndef NOISE_UTILS
# define NOISE_UTILS

// Reference noises based on https://github.com/BrianSharpe/GPU-Noise-Lib/blob/master/gpu_noise_lib.glsl

#define EUCLIDEAN_DISTANCE  0
#define MANHATTAN_DISTANCE  1
#define MINKOWSKI_DISTANCE_0_4  2

#ifdef CUSTOM_DISTANCE
# define DISTANCE_ALGORITHM CUSTOM_DISTANCE
#else
# define DISTANCE_ALGORITHM EUCLIDEAN_DISTANCE
#endif

#ifdef CUSTOM_DISTANCE_MULTIPLIER
# define DISTANCE_MULTIPLIER CUSTOM_DISTANCE_MULTIPLIER
#else
# define DISTANCE_MULTIPLIER 1.0
#endif

float MinkowskiDistance(float3 p, float d)
{
    float3 v = abs(p);
    return pow(pow(v.x, d) + pow(v.y, d) + pow(v.z, d), 1.0 / d);
}

float Distance(float3 p)
{
    float d;

    switch (DISTANCE_ALGORITHM)
    {
        case MANHATTAN_DISTANCE:
            d = abs(p.x) + abs(p.y) + abs(p.z); break;
        case MINKOWSKI_DISTANCE_0_4:
            d = MinkowskiDistance(p, 0.4); break;
        case EUCLIDEAN_DISTANCE:
        default:
            d = length(p); break;
    }

    return d * DISTANCE_MULTIPLIER;
}

float Distance(float2 p) { return Distance(float3(p, 0)); }

#define NOISE_TEMPLATE(NAME, COORDINATE_TYPE, RETURN_TYPE, FUNC_CALL) \
RETURN_TYPE Generate##NAME##Noise(COORDINATE_TYPE coordinate, float frequency, int octaveCount, float persistence, float lacunarity, float seed) \
{ \
    RETURN_TYPE total = 0.0f; \
    if (DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) \
        total = 1e20; \
\
    float amplitude = 1.0f; \
    float totalAmplitude = 0.0f; \
\
    for (int octaveIndex = 0; octaveIndex < octaveCount; octaveIndex++) \
    { \
        if (DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) \
            total = min(total, FUNC_CALL * amplitude); \
        else \
            total += FUNC_CALL * amplitude; \
        totalAmplitude += amplitude; \
        amplitude *= persistence; \
        frequency *= lacunarity; \
    } \
 \
    return total / ((DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) ? 1 : totalAmplitude); \
}

#define RIDGED_NOISE_TEMPLATE(NAME, COORDINATE_TYPE, RETURN_TYPE, FUNC_CALL) \
RETURN_TYPE GenerateRidged##NAME##Noise(COORDINATE_TYPE coordinate, float frequency, int octaveCount, float persistence, float lacunarity, float seed) \
{ \
    RETURN_TYPE total = 0.0f; \
    if (DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) \
        total = 1e20; \
\
    float amplitude = 1.0f; \
    float totalAmplitude = 0.0f; \
\
    for (int octaveIndex = 0; octaveIndex < octaveCount; octaveIndex++) \
    { \
        if (DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) \
            total = abs(min(total, FUNC_CALL * amplitude)); \
        else \
            total += abs(FUNC_CALL * amplitude); \
        totalAmplitude += amplitude; \
        amplitude *= persistence; \
        frequency *= lacunarity; \
    } \
 \
    return total / ((DISTANCE_ALGORITHM != EUCLIDEAN_DISTANCE) ? 1 : totalAmplitude); \
}

// #define CURL_NOISE_2D_TEMPLATE(NAME, FUNC_CALL) \
// float2 Generate##NAME##CurlNoise(float2 coordinate, float frequency, int octaveCount, float persistence, float lacunarity) \
// { \
//     float2 total = float2(0.0f, 0.0f); \
// \
//     float amplitude = 1.0f; \
//     float totalAmplitude = 0.0f; \
// \
//     for (int octaveIndex = 0; octaveIndex < octaveCount; octaveIndex++) \
//     { \
//         float2 derivatives = FUNC_CALL(coordinate * frequency).yz; \
//         total += derivatives * amplitude; \
// \
//         totalAmplitude += amplitude; \
//         amplitude *= persistence; \
//         frequency *= lacunarity; \
//     } \
// \
//     return float2(total.y, -total.x) / totalAmplitude; \
// }

// #define CURL_NOISE_3D_TEMPLATE(NAME, FUNC_CALL) \
// float3 Generate##NAME##CurlNoise(float3 coordinate, float frequency, int octaveCount, float persistence, float lacunarity) \
// { \
//     float2 total[3] = { float2(0.0f, 0.0f), float2(0.0f, 0.0f), float2(0.0f, 0.0f) }; \
// \
//     float amplitude = 1.0f; \
//     float totalAmplitude = 0.0f; \
// \
//     float2 points[3] = \
//     { \
//         coordinate.zy, \
//         coordinate.xz + 100.0f, \
//         coordinate.yx + 200.0f \
//     }; \
// \
//     for (int octaveIndex = 0; octaveIndex < octaveCount; octaveIndex++) \
//     { \
//         for (int i = 0; i < 3; i++) \
//         { \
//             float2 derivatives = FUNC_CALL(points[i] * frequency).yz; \
//             total[i] += derivatives * amplitude; \
//         } \
// \
//         totalAmplitude += amplitude; \
//         amplitude *= persistence; \
//         frequency *= lacunarity; \
//     } \
// \
//     return float3( \
//         (total[2].x - total[1].y), \
//         (total[0].x - total[2].y), \
//         (total[1].x - total[0].y)) / totalAmplitude; \
// }

#ifdef UNITY_CUSTOM_TEXTURE_INCLUDED

float GenerateNoise(v2f_customrendertexture i, int seed);

// This function requires GenerateNoise(v2f_customrendertexture i, int seed) to be defined
float4 GenerateNoiseForChannels(v2f_customrendertexture i, int channels, int seed)
{
    switch (channels)
    {
        case 0: // RRRR
            return GenerateNoise(i, seed).rrrr;
        case 1: // R
            return float4(GenerateNoise(i, seed), 0, 0, 1);
        case 2: // RG
            return float4(GenerateNoise(i, seed), GenerateNoise(i, seed + 42), 0, 1);
        case 3: // RGB
            return float4(GenerateNoise(i, seed), GenerateNoise(i, seed + 42), GenerateNoise(i, seed - 69), 1);
        case 4: // RGBA
            return float4(GenerateNoise(i, seed), GenerateNoise(i, seed + 42), GenerateNoise(i, seed - 69), GenerateNoise(i, seed + 5359));
        default:
            return GenerateNoise(i, seed).rrrr;
    }
}

float3 RandomOffset3(int seed)
{
    float3 v = float3(-6.747, 8.488, 3.584) * seed;

    v %= 5000;

    return v;
}

float3 GetNoiseUVs(v2f_customrendertexture i, float4 customUvs, inout int seed)
{
#if defined(USE_CUSTOM_UV)
    // We apply another offset based on UV.a.
    // This is epsecially useful to generate different noises when you have multiple UV sets in the same texture
    seed += customUvs.a * 100;
#endif

    float3 offset = RandomOffset3(seed);

#ifdef USE_CUSTOM_UV
    return customUvs.xyz + offset;
#else
    return GetDefaultUVs(i) + offset;
#endif
}

#endif

float WhiteNoise(float3 uvs)
{
    float3 smallValue = sin(uvs);
    float random = dot(smallValue, float3(12.9898, 78.233, 37.719));
    random = frac(sin(random) * 143758.5453);
    return random;
}

#endif