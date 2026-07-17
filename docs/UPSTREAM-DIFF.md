# FNA HLSL Fork — Upstream 对比与迁移指南

本文档记录 FNA HLSL fork 与上游 [FNA-XNA/FNA](https://github.com/FNA-XNA/FNA) 的差异。从上游迁移到此 fork 的用户请关注以下变更。

## 架构差异

| | 上游 | 本 fork |
|---|---|---|
| 图形后端 | FNA3D (OpenGL/D3D11/Metal) | **FNA3D_HLSL** (Vulkan only) |
| Shader 编译 | MojoShader (runtime) | **DXC → SPIR-V** (build time) |
| Shader 格式 | .fxb | **.feb** (FNA3D Effect Binary) |
| SDL 版本 | SDL2 / SDL3 双轨 | **仅 SDL3** |
| 平台支持 | Win/Mac/Linux | **仅 Linux** (Vulkan 驱动) |

## 破坏性变更 (Breaking Changes)

### 1. SDL2 后端已移除

上游通过 `FNA_PLATFORM_BACKEND=SDL2` 环境变量支持 SDL2 后端。本 fork **仅支持 SDL3**，`SDL2_FNAPlatform.cs` 和 `lib/SDL2-CS` 子模块已删除。设置 `FNA_PLATFORM_BACKEND=SDL2` 无效。

### 2. 仅支持 Vulkan

上游 FNA3D 支持 OpenGL、D3D11、Metal 和 SDL_GPU 多后端。本 fork 的 FNA3D_HLSL 仅支持 SDL_GPU 的 Vulkan 驱动。着色器仅以 SPIR-V 格式提供，无后备方案。

- macOS / iOS：不支持（SDL_GPU 无 Vulkan-on-Metal 路径）
- 软件渲染（llvmpipe/lavapipe）可用于 CI/无 GPU 环境

## 行为变更 (Non-Breaking)

### Stock Effect 内部实现

6 个内置 Effect 的公共 API 完全兼容，但内部实现已从 MojoShader 的 32 着色器排列切换为多 technique HLSL：

- BasicEffect：4 techniques（PNT/PT/PC/PCT）
- AlphaTestEffect：2 techniques（PT/PCT）
- DualTextureEffect：2 techniques（PTT/PCTT）
- SkinnedEffect：1 technique（移除 Color 输入限制）
- EnvironmentMapEffect / SpriteEffect：无变化

所有 Effect 的公共属性（`DiffuseColor`、`LightingEnabled`、`TextureEnabled` 等）与上游一致，用户代码无需修改。

### 严格顶点属性约定 (C1-C5)

本 fork 的 HLSL 着色器遵循严格的顶点属性对应约定（详见 `FNA_Test/CLAUDE.md`）。对用户的直接影响：如果自行编写自定义 Effect 使用的 HLSL 着色器，必须确保 VS_INPUT 字段精确匹配顶点声明。使用内置 Effect 则不受影响。

## 不涉及的功能

以下上游功能未修改，与上游行为一致：

- 全部 XNA 4.0 API（输入、音频、内容管线）
- Game / GameWindow / GameTime 生命周期
- SpriteBatch / SpriteFont
- Effect 类体系（Effect、EffectPass、EffectTechnique、EffectParameter 的公共 API）
- 除上述 2 项外的所有 Effect 公共属性默认值

## 迁移检查清单

1. 检查 `SkinnedEffect.SetBoneTransforms()` 调用：骨骼数是否超过 12
2. 如果期望 `EnvironmentMapSpecular` 默认关闭，显式设为 `Vector3.Zero`
3. 移除所有 `FNA_PLATFORM_BACKEND=SDL2` 相关代码
4. 确保运行环境有 Vulkan 驱动（Linux + radv/AMDVLK，或 llvmpipe/lavapipe）
5. 子模块 URL 变更：`lib/FNA3D` 指向 `https://github.com/isncg/FNA3D.git`
