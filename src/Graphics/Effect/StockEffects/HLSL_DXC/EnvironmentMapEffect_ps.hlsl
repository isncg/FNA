// EnvironmentMapEffect pixel shader — full XNA compatibility.
// Handles: cubemap reflection, Fresnel, environment map amount, fog.

Texture2D<float4> Texture : register(t0);
SamplerState TextureSampler : register(s0);
TextureCube<float4> EnvironmentMap : register(t1);
SamplerState EnvironmentMapSampler : register(s1);

float4 EnvironmentMapSpecular : register(c15);
float EnvironmentMapAmount    : register(c16);
float FresnelFactor           : register(c17);
float3 FogColor               : register(c29);
int ShaderIndex               : register(c19);

float4 PSMain(
    float4 position    : SV_POSITION,
    float3 worldPos    : TEXCOORD0,
    float3 worldNormal : TEXCOORD1,
    float2 texCoord    : TEXCOORD2,
    float3 eyeDir      : TEXCOORD3,
    float4 diffuse     : COLOR0,
    float  fogFactor   : TEXCOORD4
) : SV_TARGET0
{
    bool fresnelEnabled = ((ShaderIndex & 2) != 0);

    // Sample base texture and apply diffuse lighting
    float4 color = Texture.Sample(TextureSampler, texCoord) * diffuse;

    // Environment map reflection
    float3 reflectVec = reflect(-eyeDir, worldNormal);

    if (fresnelEnabled)
    {
        // Fresnel: reflection amount increases at grazing angles
        float fresnel = FresnelFactor;
        fresnel += (1.0 - FresnelFactor) * pow(1.0 - abs(dot(worldNormal, eyeDir)), 5.0);

        float4 envColor = EnvironmentMap.Sample(EnvironmentMapSampler, reflectVec);
        color.rgb = lerp(color.rgb, envColor.rgb * EnvironmentMapSpecular.rgb,
                         fresnel * EnvironmentMapAmount);
    }
    else
    {
        float4 envColor = EnvironmentMap.Sample(EnvironmentMapSampler, reflectVec);
        color.rgb = lerp(color.rgb, envColor.rgb * EnvironmentMapSpecular.rgb,
                         EnvironmentMapAmount);
    }

    // Apply fog
    float fog = saturate(fogFactor);
    color.rgb = lerp(color.rgb, FogColor * color.a, fog);

    return color;
}
