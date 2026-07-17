// SkinnedEffect vertex shader — strict HLSL vertex convention.
// Supports up to 12 bones (48 registers). ShaderIndex controls fog/lighting.
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

// Bones (12 bones × 4 registers each = 48 registers starting at c30)
float4x4 Bone0  : register(c30);  float4x4 Bone1  : register(c34);
float4x4 Bone2  : register(c38);  float4x4 Bone3  : register(c42);
float4x4 Bone4  : register(c46);  float4x4 Bone5  : register(c50);
float4x4 Bone6  : register(c54);  float4x4 Bone7  : register(c58);
float4x4 Bone8  : register(c62);  float4x4 Bone9  : register(c66);
float4x4 Bone10 : register(c70);  float4x4 Bone11 : register(c74);

// Lights (after bones)
float4 DirLight0Direction    : register(c78);
float4 DirLight0DiffuseColor : register(c79);
float4 DirLight0SpecularColor : register(c80);
float4 DirLight1Direction    : register(c81);
float4 DirLight1DiffuseColor : register(c82);
float4 DirLight1SpecularColor : register(c83);
float4 DirLight2Direction    : register(c84);
float4 DirLight2DiffuseColor : register(c85);
float4 DirLight2SpecularColor : register(c86);

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

// ─── Bone lookup ──────────────────────────────────────────────────────

float4x4 GetBone(int index)
{
    if (index == 0) return Bone0;   if (index == 1) return Bone1;
    if (index == 2) return Bone2;   if (index == 3) return Bone3;
    if (index == 4) return Bone4;   if (index == 5) return Bone5;
    if (index == 6) return Bone6;   if (index == 7) return Bone7;
    if (index == 8) return Bone8;   if (index == 9) return Bone9;
    if (index == 10) return Bone10; if (index == 11) return Bone11;
    return float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1); // identity fallback
}

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

    // Bone skinning — BlendIndices as int (cast from float, Byte4 in XNA)
    int4 indices = int4(input.BlendIndices);
    float4x4 skinMatrix = GetBone(indices.x) * input.BlendWeights.x
                        + GetBone(indices.y) * input.BlendWeights.y
                        + GetBone(indices.z) * input.BlendWeights.z
                        + GetBone(indices.w) * input.BlendWeights.w;

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
