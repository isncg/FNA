// DualTextureEffect pixel shader — full XNA compatibility.
// Blends two textures multiplicatively: result = base * overlay * 2.0 * diffuse.
// Fog is applied when FogFactor > 0.

Texture2D<float4> Texture  : register(t0);
Texture2D<float4> Texture2 : register(t1);
SamplerState TextureSampler  : register(s0);
SamplerState Texture2Sampler : register(s1);

float3 FogColor : register(c7);

float4 PSMain(
    float4 position  : SV_POSITION,
    float2 texCoord  : TEXCOORD0,
    float2 texCoord2 : TEXCOORD1,
    float4 diffuse   : COLOR0,
    float  fogFactor : TEXCOORD2
) : SV_TARGET0
{
    float4 base = Texture.Sample(TextureSampler, texCoord);
    float4 overlay = Texture2.Sample(Texture2Sampler, texCoord2);

    base.rgb *= 2.0;
    float4 color = base * overlay * diffuse;

    // Apply fog
    float fog = saturate(fogFactor);
    color.rgb = lerp(color.rgb, FogColor * color.a, fog);

    return color;
}
