// SkinnedEffect vertex shader — strict HLSL vertex convention.
// Supports up to 72 bones (288 registers). ShaderIndex controls fog/lighting.
//
// ShaderIndex bit layout (matching SkinnedEffect.cs OnApply):
//   bit 0: fogEnabled (0=enabled, 1=disabled)
//   bit 1: WeightsPerVertex == 2  (+2)
//   bit 2: WeightsPerVertex == 4  (+4)
//   lighting (no overlap with wpv bits):
//     0:  3 lights, vertex
//     +6: 1 light, vertex   (bits 1+2)
//     +12: pixel lighting   (bits 2+3)

float4x4 World              : register(c0);
float4x4 WorldInverseTranspose : register(c4);
float4x4 WorldViewProj      : register(c8);
float4 DiffuseColor         : register(c12);
float4 EmissiveColor        : register(c13);
float4 SpecularColor        : register(c14);
float4 EyePosition          : register(c15);
float4 FogVector            : register(c16);
int ShaderIndex             : register(c17);

// 72 bones × 4 registers each = 288 registers (c30–c317)
float4x4 Bones[72]          : register(c30);

// Lights (after bones, at c318+)
float4 DirLight0Direction    : register(c318);
float4 DirLight0DiffuseColor : register(c319);
float4 DirLight0SpecularColor : register(c320);
float4 DirLight1Direction    : register(c321);
float4 DirLight1DiffuseColor : register(c322);
float4 DirLight1SpecularColor : register(c323);
float4 DirLight2Direction    : register(c324);
float4 DirLight2DiffuseColor : register(c325);
float4 DirLight2SpecularColor : register(c326);

// ─── VS_INPUT (P, N, T, BlendIndices(float4), BlendWeights) — no Color ─

struct VS_INPUT
{
    float4 Position      : POSITION0;
    float3 Normal        : NORMAL0;
    float2 TexCoord      : TEXCOORD0;
    float4 BlendIndices  : BLENDINDICES0;
    float4 BlendWeights  : BLENDWEIGHT0;
};

// ─── VS_OUTPUT ────────────────────────────────────────────────────────

struct VS_OUTPUT
{
    float4 Position     : SV_POSITION;
    float3 WorldNormal  : TEXCOORD0;
    float2 TexCoord     : TEXCOORD1;
    float4 Diffuse      : COLOR0;
    float  FogFactor    : TEXCOORD2;
    float3 EyeDir       : TEXCOORD3;
    float3 WorldPos     : TEXCOORD4;
};

// ─── Shared vertex lighting helper ────────────────────────────────────

float3 ComputeVertexLighting(float3 worldNormal, float3 eyeDir, int lightingMode, float3 diffuse)
{
    float3 totalDiffuse = EmissiveColor.rgb;
    bool oneLight = (lightingMode == 2);

    float3 l0 = normalize(DirLight0Direction.xyz);
    totalDiffuse += max(dot(worldNormal, l0), 0.0) * DirLight0DiffuseColor.rgb;

    if (!oneLight)
    {
        float3 l1 = normalize(DirLight1Direction.xyz);
        totalDiffuse += max(dot(worldNormal, l1), 0.0) * DirLight1DiffuseColor.rgb;
        float3 l2 = normalize(DirLight2Direction.xyz);
        totalDiffuse += max(dot(worldNormal, l2), 0.0) * DirLight2DiffuseColor.rgb;
    }

    return totalDiffuse * diffuse;
}

// ─── Entry: VSMain (single technique, fixed input layout) ─────────────

VS_OUTPUT VSMain(VS_INPUT input)
{
    VS_OUTPUT output;

    // Bone skinning — BlendIndices as int (cast from float)
    int4 indices = int4(input.BlendIndices);
    float4x4 skinMatrix = Bones[indices.x] * input.BlendWeights.x
                        + Bones[indices.y] * input.BlendWeights.y
                        + Bones[indices.z] * input.BlendWeights.z
                        + Bones[indices.w] * input.BlendWeights.w;

    float4 skinnedPos = mul(input.Position, skinMatrix);
    float3x3 skinMatrix3x3 = (float3x3) skinMatrix;
    float3 skinnedNormal = mul(input.Normal, skinMatrix3x3);

    float4 worldPos = mul(skinnedPos, World);
    output.Position = mul(skinnedPos, WorldViewProj);
    output.WorldPos = worldPos.xyz;
    output.TexCoord = input.TexCoord;

    float3x3 worldInvTranspose3x3 = (float3x3) WorldInverseTranspose;
    output.WorldNormal = normalize(mul(skinnedNormal, worldInvTranspose3x3));

    float3 eyePos = EyePosition.xyz;
    output.EyeDir = normalize(eyePos - worldPos.xyz);

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    // Decode lighting mode matching SkinnedEffect.cs OnApply encoding:
    //   0:  3 lights, vertex lighting
    //   6:  1 light, vertex lighting  (bits 1+2)
    //   12: pixel lighting            (bits 2+3)
    int lightingMode;
    if ((ShaderIndex & 12) == 12)
        lightingMode = 3;  // pixel
    else if ((ShaderIndex & 6) == 6)
        lightingMode = 2;  // vertex1Light
    else
        lightingMode = 1;  // vertex3Lights (default — always lit in SkinnedEffect)

    // No vertex color in SkinnedEffect — use DiffuseColor directly
    float3 baseDiffuse = DiffuseColor.rgb;

    if (lightingMode == 1 || lightingMode == 2)
    {
        float3 lighting = ComputeVertexLighting(output.WorldNormal, output.EyeDir, lightingMode, baseDiffuse);
        output.Diffuse = float4(lighting, DiffuseColor.a);
    }
    else if (lightingMode == 3)
    {
        output.Diffuse = float4(baseDiffuse, DiffuseColor.a);
    }
    else
    {
        output.Diffuse = float4(baseDiffuse, DiffuseColor.a);
    }

    // FogVector expects the model-space (post-skinning) position, not clip space
    output.FogFactor = fogEnabled ? dot(skinnedPos, FogVector) : 0.0;

    return output;
}
