// EnvironmentMapEffect vertex shader — full XNA compatibility.
// ShaderIndex bit layout:
//   bit 0: fogEnabled (0=enabled, 1=disabled)
//   bit 1: fresnelEnabled
//   bit 2: specularEnabled
//   bit 3: oneLight (0=3 lights, 1=1 light)

float4x4 World              : register(c0);
float4x4 WorldInverseTranspose : register(c4);
float4x4 WorldViewProj      : register(c8);
float4 EyePosition          : register(c12);
float4 DiffuseColor         : register(c13);
float4 EmissiveColor        : register(c14);
float4 EnvironmentMapSpecular : register(c15);
float EnvironmentMapAmount  : register(c16);
float FresnelFactor         : register(c17);
float4 FogVector            : register(c18);
int ShaderIndex             : register(c19);

// Lighting: 3 directional lights
float4 DirLight0Direction    : register(c20);
float4 DirLight0DiffuseColor : register(c21);
float4 DirLight0SpecularColor : register(c22);
float4 DirLight1Direction    : register(c23);
float4 DirLight1DiffuseColor : register(c24);
float4 DirLight1SpecularColor : register(c25);
float4 DirLight2Direction    : register(c26);
float4 DirLight2DiffuseColor : register(c27);
float4 DirLight2SpecularColor : register(c28);

struct VS_INPUT
{
    float4 Position : POSITION0;
    float3 Normal   : NORMAL0;
    float2 TexCoord : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 Position     : SV_POSITION;
    float3 WorldPos     : TEXCOORD0;
    float3 WorldNormal  : TEXCOORD1;
    float2 TexCoord     : TEXCOORD2;
    float3 EyeDir       : TEXCOORD3;
    float4 Diffuse      : COLOR0;
    float  FogFactor    : TEXCOORD4;
};

float3 ComputeDirectionalLights(float3 worldNormal, float3 eyeDir, float3 diffuse, float specularPower)
{
    bool fogEnabled = ((ShaderIndex & 1) == 0);
    bool fresnelEnabled = ((ShaderIndex & 2) != 0);
    bool specularEnabled = ((ShaderIndex & 4) != 0);
    bool oneLight = ((ShaderIndex & 8) != 0);

    // Ambient = emissive
    float3 totalDiffuse = EmissiveColor.rgb;
    float3 totalSpecular = float3(0, 0, 0);

    // Light 0 is always on
    {
        float3 lightDir = normalize(DirLight0Direction.xyz);
        float nDotL = max(dot(worldNormal, lightDir), 0.0);
        totalDiffuse += nDotL * DirLight0DiffuseColor.rgb;

        if (specularEnabled)
        {
            float3 halfVec = normalize(lightDir + eyeDir);
            float spec = pow(max(dot(worldNormal, halfVec), 0.0), specularPower);
            totalSpecular += spec * DirLight0SpecularColor.rgb;
        }
    }

    if (!oneLight)
    {
        // Light 1
        float3 lightDir1 = normalize(DirLight1Direction.xyz);
        float nDotL1 = max(dot(worldNormal, lightDir1), 0.0);
        totalDiffuse += nDotL1 * DirLight1DiffuseColor.rgb;
        if (specularEnabled)
        {
            float3 halfVec = normalize(lightDir1 + eyeDir);
            float spec = pow(max(dot(worldNormal, halfVec), 0.0), specularPower);
            totalSpecular += spec * DirLight1SpecularColor.rgb;
        }

        // Light 2
        float3 lightDir2 = normalize(DirLight2Direction.xyz);
        float nDotL2 = max(dot(worldNormal, lightDir2), 0.0);
        totalDiffuse += nDotL2 * DirLight2DiffuseColor.rgb;
        if (specularEnabled)
        {
            float3 halfVec = normalize(lightDir2 + eyeDir);
            float spec = pow(max(dot(worldNormal, halfVec), 0.0), specularPower);
            totalSpecular += spec * DirLight2SpecularColor.rgb;
        }
    }

    return totalDiffuse * diffuse + totalSpecular * EnvironmentMapSpecular.rgb;
}

VS_OUTPUT VSMain(VS_INPUT input)
{
    VS_OUTPUT output;

    float4 worldPos = mul(input.Position, World);
    // WorldViewProj already contains World — transform model-space position directly
    output.Position = mul(input.Position, WorldViewProj);
    output.WorldPos = worldPos.xyz;
    output.TexCoord = input.TexCoord;

    float3x3 worldInvTranspose3x3 = (float3x3) WorldInverseTranspose;
    output.WorldNormal = normalize(mul(input.Normal, worldInvTranspose3x3));

    float3 eyePos = EyePosition.xyz;
    output.EyeDir = normalize(eyePos - worldPos.xyz);

    bool fogEnabled = ((ShaderIndex & 1) == 0);

    float3 lighting = ComputeDirectionalLights(
        output.WorldNormal, output.EyeDir, DiffuseColor.rgb,
        EnvironmentMapSpecular.w /* specularPower in .w */
    );
    output.Diffuse = float4(lighting, DiffuseColor.a);

    // FogVector expects the model-space input position, not clip space
    output.FogFactor = fogEnabled ? dot(input.Position, FogVector) : 0.0;

    return output;
}
