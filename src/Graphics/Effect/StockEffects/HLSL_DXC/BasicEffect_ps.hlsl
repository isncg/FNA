// BasicEffect pixel shader — full XNA compatibility.
// Handles: pixel lighting, specular, texture sampling, fog.

Texture2D<float4> Texture : register(t0);
SamplerState TextureSampler : register(s0);

float4 DiffuseColor         : register(c12);
float4 EmissiveColor        : register(c13);
float4 SpecularColor        : register(c14); // .w = SpecularPower
float4 EyePosition          : register(c15);
float3 FogColor             : register(c27);
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

float3 ComputePixelLighting(float3 worldNormal, float3 eyeDir, float3 diffuse, int lightingMode)
{
    float specularPower = SpecularColor.w;
    float3 totalDiffuse = EmissiveColor.rgb;
    float3 totalSpecular = float3(0, 0, 0);

    bool oneLight = (lightingMode == 2);

    // Light 0
    {
        float3 lightDir = normalize(DirLight0Direction.xyz);
        float nDotL = max(dot(worldNormal, lightDir), 0.0);
        totalDiffuse += nDotL * DirLight0DiffuseColor.rgb;
        if (specularPower > 0.0)
        {
            float3 halfVec = normalize(lightDir + eyeDir);
            totalSpecular += pow(max(dot(worldNormal, halfVec), 0.0), specularPower)
                           * DirLight0SpecularColor.rgb;
        }
    }

    if (!oneLight)
    {
        // Light 1
        float3 l1 = normalize(DirLight1Direction.xyz);
        float n1 = max(dot(worldNormal, l1), 0.0);
        totalDiffuse += n1 * DirLight1DiffuseColor.rgb;
        if (specularPower > 0.0)
        {
            float3 h1 = normalize(l1 + eyeDir);
            totalSpecular += pow(max(dot(worldNormal, h1), 0.0), specularPower)
                           * DirLight1SpecularColor.rgb;
        }
        // Light 2
        float3 l2 = normalize(DirLight2Direction.xyz);
        float n2 = max(dot(worldNormal, l2), 0.0);
        totalDiffuse += n2 * DirLight2DiffuseColor.rgb;
        if (specularPower > 0.0)
        {
            float3 h2 = normalize(l2 + eyeDir);
            totalSpecular += pow(max(dot(worldNormal, h2), 0.0), specularPower)
                           * DirLight2SpecularColor.rgb;
        }
    }

    return totalDiffuse * diffuse + totalSpecular * SpecularColor.rgb;
}

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
        float3 lighting = ComputePixelLighting(normalize(worldNormal), normalize(eyeDir),
                                                color.rgb, lightingMode);
        color.rgb = lighting;
    }

    // Apply fog
    float fog = saturate(fogFactor);
    color.rgb = lerp(color.rgb, FogColor * color.a, fog);

    return color;
}
