// AlphaTestEffect vertex shader — strict HLSL vertex convention.
// Two entry points: PT (Position+TexCoord), PCT (Position+Color+TexCoord).
// Technique selected by vertexColorEnabled in OnApply.
//
// ShaderIndex bit layout:
//   bit 0: fogEnabled (0=enabled, 1=disabled)
//   bit 1: unused (was vertexColorEnabled, now always 0)
//   bit 2: isEqNe (affects PS only)

float4x4 WorldViewProj : register(c0);
float4 DiffuseColor     : register(c4);
float4 FogVector        : register(c5);
int ShaderIndex         : register(c6);

// ─── VS_INPUT structs ─────────────────────────────────────────────────

struct VS_INPUT_PT
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
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
    float4 Position  : SV_POSITION;
    float2 TexCoord  : TEXCOORD0;
    float4 Diffuse   : COLOR0;
    float  FogFactor : TEXCOORD1;
};

// ─── Entry: PT (Position, TexCoord) — no vertex color ─────────────────

VS_OUTPUT VSMain_PT(VS_INPUT_PT input)
{
    VS_OUTPUT output;

    output.Position = mul(input.Position, WorldViewProj);
    output.TexCoord = input.TexCoord;

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = DiffuseColor;

    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}

// ─── Entry: PCT (Position, Color, TexCoord) — vertex color enabled ────

VS_OUTPUT VSMain_PCT(VS_INPUT_PCT input)
{
    VS_OUTPUT output;

    output.Position = mul(input.Position, WorldViewProj);
    output.TexCoord = input.TexCoord;

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    output.Diffuse = float4(DiffuseColor.rgb * input.Color.rgb,
                            DiffuseColor.a * input.Color.a);

    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}
