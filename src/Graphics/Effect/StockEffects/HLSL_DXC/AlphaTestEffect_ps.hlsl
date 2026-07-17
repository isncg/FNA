// AlphaTestEffect pixel shader — full XNA compatibility.
// Handles all 8 alpha-test compare functions via AlphaTest uniform encoding.
//
// ShaderIndex bit 2 (isEqNe):
//   0 = Less/Greater mode:  clip((color.a < AlphaTest.x) ? AlphaTest.z : AlphaTest.w)
//   1 = Equal/NotEqual mode: clip((abs(color.a - AlphaTest.x) < AlphaTest.y) ? AlphaTest.z : AlphaTest.w)
//
// Fog: applied when FogFactor > 0, using XNA's lerp(diffuse, FogColor, fogFactor)

Texture2D<float4> Texture : register(t0);
SamplerState TextureSampler : register(s0);

float4 AlphaTest    : register(c7);
int ShaderIndex     : register(c6);
float3 FogColor     : register(c8);

float4 PSMain(
    float4 position  : SV_POSITION,
    float2 texCoord  : TEXCOORD0,
    float4 diffuse   : COLOR0,
    float  fogFactor : TEXCOORD1
) : SV_TARGET0
{
    float4 color = Texture.Sample(TextureSampler, texCoord) * diffuse;

    bool isEqNe = ((ShaderIndex & 4) != 0);

    if (isEqNe)
    {
        // Equal/NotEqual mode
        clip((abs(color.a - AlphaTest.x) < AlphaTest.y) ? AlphaTest.z : AlphaTest.w);
    }
    else
    {
        // Less/Greater mode
        clip((color.a < AlphaTest.x) ? AlphaTest.z : AlphaTest.w);
    }

    // Apply fog (XNA convention)
    float fog = saturate(fogFactor);
    color.rgb = lerp(color.rgb, FogColor * color.a, fog);

    return color;
}
