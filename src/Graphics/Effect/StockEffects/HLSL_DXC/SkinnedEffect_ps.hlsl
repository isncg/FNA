// SkinnedEffect pixel shader — full XNA compatibility.

Texture2D<float4> Texture : register(t0);
SamplerState TextureSampler : register(s0);

float4 DiffuseColor         : register(c12);
float4 EmissiveColor        : register(c13);
float4 SpecularColor        : register(c14);
float4 EyePosition          : register(c15);
float3 FogColor             : register(c87);
int ShaderIndex             : register(c17);

float4 DirLight0Direction    : register(c78);
float4 DirLight0DiffuseColor : register(c79);
float4 DirLight0SpecularColor : register(c80);
float4 DirLight1Direction    : register(c81);
float4 DirLight1DiffuseColor : register(c82);
float4 DirLight1SpecularColor : register(c83);
float4 DirLight2Direction    : register(c84);
float4 DirLight2DiffuseColor : register(c85);
float4 DirLight2SpecularColor : register(c86);

float4 PSMain(
    float4 position    : SV_POSITION,
    float3 worldNormal : TEXCOORD0,
    float2 texCoord    : TEXCOORD1,
    float4 diffuse     : COLOR0,
    float  fogFactor   : TEXCOORD2,
    float3 eyeDir      : TEXCOORD3,
    float3 worldPos    : TEXCOORD4
) : SV_TARGET0
{
    bool textureEnabled = ((ShaderIndex & 4) != 0);
    int lightingMode = (ShaderIndex >> 3) & 3;

    float4 color;
    if (textureEnabled)
    {
        color = Texture.Sample(TextureSampler, texCoord) * diffuse;
    }
    else
    {
        color = diffuse;
    }

    if (lightingMode == 3)
    {
        // Pixel lighting
        float3 N = normalize(worldNormal);
        float3 V = normalize(eyeDir);
        float specularPower = SpecularColor.w;
        float3 totalDiffuse = EmissiveColor.rgb;
        float3 totalSpecular = float3(0, 0, 0);

        float3 l0 = normalize(DirLight0Direction.xyz);
        totalDiffuse += max(dot(N, l0), 0.0) * DirLight0DiffuseColor.rgb;
        if (specularPower > 0.0) {
            float3 h = normalize(l0 + V);
            totalSpecular += pow(max(dot(N, h), 0.0), specularPower) * DirLight0SpecularColor.rgb;
        }
        float3 l1 = normalize(DirLight1Direction.xyz);
        totalDiffuse += max(dot(N, l1), 0.0) * DirLight1DiffuseColor.rgb;
        if (specularPower > 0.0) {
            float3 h = normalize(l1 + V);
            totalSpecular += pow(max(dot(N, h), 0.0), specularPower) * DirLight1SpecularColor.rgb;
        }
        float3 l2 = normalize(DirLight2Direction.xyz);
        totalDiffuse += max(dot(N, l2), 0.0) * DirLight2DiffuseColor.rgb;
        if (specularPower > 0.0) {
            float3 h = normalize(l2 + V);
            totalSpecular += pow(max(dot(N, h), 0.0), specularPower) * DirLight2SpecularColor.rgb;
        }

        color.rgb = totalDiffuse * color.rgb + totalSpecular * SpecularColor.rgb;
    }

    float fog = saturate(fogFactor);
    color.rgb = lerp(color.rgb, FogColor * color.a, fog);

    return color;
}
