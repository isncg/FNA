// SpriteEffect vertex shader — transform to clip space, pass texcoord + color.
// VS_INPUT field order MUST match FNA's VertexPositionColorTexture declaration
// (Position, Color, TexCoord): DXC assigns SPIR-V locations in declaration
// order, and the SDL_GPU driver assigns vertex attribute locations in the
// same sequential order.

float4x4 MatrixTransform : register(c0);

struct VS_INPUT
{
    float4 Position : POSITION0;
    float4 Color    : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 Color    : COLOR0;
};

VS_OUTPUT VSMain(VS_INPUT input)
{
    VS_OUTPUT output;
    output.Position = mul(input.Position, MatrixTransform);
    output.TexCoord = input.TexCoord;
    output.Color = input.Color;
    return output;
}
