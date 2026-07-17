// DualTextureEffect vertex shader — strict HLSL vertex convention.
// Two entry points: PTT (Position+TexCoord0+TexCoord1), PCTT (+Color).
// Technique selected by vertexColorEnabled in OnApply.
//
// ShaderIndex bit layout:
//   bit 0: fogEnabled (0=enabled, 1=disabled)
//   bit 1: unused (was vertexColorEnabled, now always 0)

float4x4 WorldViewProj : register(c0);
float4 DiffuseColor     : register(c4);
float4 FogVector        : register(c5);
int ShaderIndex         : register(c6);

// ─── VS_INPUT structs ─────────────────────────────────────────────────

struct VS_INPUT_PTT
{
    float4 Position  : POSITION0;
    float2 TexCoord  : TEXCOORD0;
    float2 TexCoord2 : TEXCOORD1;
};

struct VS_INPUT_PCTT
{
    float4 Position  : POSITION0;
    float4 Color     : COLOR0;
    float2 TexCoord  : TEXCOORD0;
    float2 TexCoord2 : TEXCOORD1;
};

// ─── Shared VS_OUTPUT ─────────────────────────────────────────────────

struct VS_OUTPUT
{
    float4 Position  : SV_POSITION;
    float2 TexCoord  : TEXCOORD0;
    float2 TexCoord2 : TEXCOORD1;
    float4 Diffuse   : COLOR0;
    float  FogFactor : TEXCOORD2;
};

// ─── Entry: PTT (Position, TexCoord0, TexCoord1) — no vertex color ────

VS_OUTPUT VSMain_PTT(VS_INPUT_PTT input)
{
    VS_OUTPUT output;
    output.Position = mul(input.Position, WorldViewProj);
    output.TexCoord = input.TexCoord;
    output.TexCoord2 = input.TexCoord2;

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = DiffuseColor;

    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;
    return output;
}

// ─── Entry: PCTT (Position, Color, TexCoord0, TexCoord1) ──────────────

VS_OUTPUT VSMain_PCTT(VS_INPUT_PCTT input)
{
    VS_OUTPUT output;
    output.Position = mul(input.Position, WorldViewProj);
    output.TexCoord = input.TexCoord;
    output.TexCoord2 = input.TexCoord2;

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = float4(DiffuseColor.rgb * input.Color.rgb,
                            DiffuseColor.a * input.Color.a);

    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;
    return output;
}
