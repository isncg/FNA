// BasicEffect vertex shader — strict HLSL vertex convention.
// One entry point per input layout (technique = input signature).
//
// ShaderIndex bit layout:
//   bit 0: fogEnabled (0=enabled, 1=disabled)
//   bit 1: unused (was vertexColorEnabled, now always 0)
//   bit 2: textureEnabled
//   bit 3-4: lighting mode (0=none, 1=vertex3Lights, 2=vertex1Light, 3=pixel)

float4x4 World              : register(c0);
float4x4 WorldInverseTranspose : register(c4);
float4x4 WorldViewProj      : register(c8);
float4 DiffuseColor         : register(c12);
float4 EmissiveColor        : register(c13);
float4 SpecularColor        : register(c14); // .w = SpecularPower
float4 EyePosition          : register(c15);
float4 FogVector            : register(c16);
int ShaderIndex             : register(c17);

float4 DirLight0Direction    : register(c18);
float4 DirLight0DiffuseColor : register(c19);
float4 DirLight0SpecularColor : register(c20);
float4 DirLight1Direction    : register(c21);
float4 DirLight1DiffuseColor : register(c22);
float4 DirLight1SpecularColor : register(c23);
float4 DirLight2Direction    : register(c24);
float4 DirLight2DiffuseColor : register(c25);
float4 DirLight2SpecularColor : register(c26);

// ─── VS_INPUT structs (one per technique) ─────────────────────────────

struct VS_INPUT_PNT
{
    float4 Position : POSITION0;
    float3 Normal   : NORMAL0;
    float2 TexCoord : TEXCOORD0;
};

struct VS_INPUT_PT
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
};

struct VS_INPUT_PC
{
    float4 Position : POSITION0;
    float4 Color    : COLOR0;
};

struct VS_INPUT_PCT
{
    float4 Position : POSITION0;
    float4 Color    : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

// ─── Shared VS_OUTPUT ─────────────────────────────────────────────────

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

    bool oneLight = (lightingMode == 2); // 1 light mode

    // Light 0 is always on when lighting is active
    float3 lightDir0 = normalize(DirLight0Direction.xyz);
    float nDotL0 = max(dot(worldNormal, lightDir0), 0.0);
    totalDiffuse += nDotL0 * DirLight0DiffuseColor.rgb;

    if (!oneLight)
    {
        // Lights 1 and 2
        float3 lightDir1 = normalize(DirLight1Direction.xyz);
        totalDiffuse += max(dot(worldNormal, lightDir1), 0.0) * DirLight1DiffuseColor.rgb;
        float3 lightDir2 = normalize(DirLight2Direction.xyz);
        totalDiffuse += max(dot(worldNormal, lightDir2), 0.0) * DirLight2DiffuseColor.rgb;
    }

    return totalDiffuse * diffuse;
}

// ─── Entry: PNT (Position, Normal, TexCoord) — always lit ─────────────

VS_OUTPUT VSMain_PNT(VS_INPUT_PNT input)
{
    VS_OUTPUT output;

    float4 worldPos = mul(input.Position, World);
    output.Position = mul(input.Position, WorldViewProj);
    output.WorldPos = worldPos.xyz;
    output.TexCoord = input.TexCoord;

    float3x3 worldInvTranspose3x3 = (float3x3) WorldInverseTranspose;
    output.WorldNormal = normalize(mul(input.Normal, worldInvTranspose3x3));

    float3 eyePos = EyePosition.xyz;
    output.EyeDir = normalize(eyePos - worldPos.xyz);

    bool fogEnabled = ((ShaderIndex & 1) == 0);
    int lightingMode = (ShaderIndex >> 3) & 3; // bits 3-4

    float3 baseDiffuse = DiffuseColor.rgb;

    if (lightingMode == 1 || lightingMode == 2)
    {
        // Vertex lighting
        float3 lighting = ComputeVertexLighting(output.WorldNormal, output.EyeDir, lightingMode, baseDiffuse);
        output.Diffuse = float4(lighting, DiffuseColor.a);
    }
    else if (lightingMode == 3)
    {
        // Pixel lighting — pass material colors, PS does the work
        output.Diffuse = float4(baseDiffuse, DiffuseColor.a);
    }
    else
    {
        // No lighting (should not happen for PNT, but handle gracefully)
        output.Diffuse = float4(baseDiffuse, DiffuseColor.a);
    }

    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}

// ─── Entry: PT (Position, TexCoord) — never lit ────────────────────────

VS_OUTPUT VSMain_PT(VS_INPUT_PT input)
{
    VS_OUTPUT output;

    output.Position = mul(input.Position, WorldViewProj);
    output.WorldPos = float3(0, 0, 0);
    output.TexCoord = input.TexCoord;
    output.WorldNormal = float3(0, 0, 0);
    output.EyeDir = float3(0, 0, 0);

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = DiffuseColor;
    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}

// ─── Entry: PC (Position, Color) — vertex color only ──────────────────

VS_OUTPUT VSMain_PC(VS_INPUT_PC input)
{
    VS_OUTPUT output;

    output.Position = mul(input.Position, WorldViewProj);
    output.WorldPos = float3(0, 0, 0);
    output.TexCoord = float2(0, 0);
    output.WorldNormal = float3(0, 0, 0);
    output.EyeDir = float3(0, 0, 0);

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = float4(DiffuseColor.rgb * input.Color.rgb,
                            DiffuseColor.a * input.Color.a);
    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}

// ─── Entry: PCT (Position, Color, TexCoord) — vertex color + texture ──

VS_OUTPUT VSMain_PCT(VS_INPUT_PCT input)
{
    VS_OUTPUT output;

    output.Position = mul(input.Position, WorldViewProj);
    output.WorldPos = float3(0, 0, 0);
    output.TexCoord = input.TexCoord;
    output.WorldNormal = float3(0, 0, 0);
    output.EyeDir = float3(0, 0, 0);

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = float4(DiffuseColor.rgb * input.Color.rgb,
                            DiffuseColor.a * input.Color.a);
    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}
