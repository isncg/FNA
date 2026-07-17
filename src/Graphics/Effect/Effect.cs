#region License
/* FNA - XNA4 Reimplementation for Desktop Platforms
 * Copyright 2009-2024 Ethan Lee and the MonoGame Team
 *
 * Released under the Microsoft Public License.
 * See LICENSE for details.
 */
#endregion

#region Using Statements
using System;
using System.Threading;
using System.Collections.Generic;
using System.Runtime.InteropServices;
#endregion

namespace Microsoft.Xna.Framework.Graphics
{
	public class Effect : GraphicsResource
	{
		#region Public Properties

		private EffectTechnique INTERNAL_currentTechnique;
		public EffectTechnique CurrentTechnique
		{
			get
			{
				return INTERNAL_currentTechnique;
			}
			set
			{
				FNA3D.FNA3D_SetEffectTechnique(
					GraphicsDevice.GLDevice,
					glEffect,
					value.TechniquePointer
				);
				INTERNAL_currentTechnique = value;
			}
		}

		public EffectParameterCollection Parameters
		{
			get;
			private set;
		}

		public EffectTechniqueCollection Techniques
		{
			get;
			private set;
		}

		#endregion

		#region Internal FNA3D Variables

		internal IntPtr glEffect;

		#endregion

		#region Private Variables

		private Dictionary<IntPtr, EffectParameter> samplerMap = new Dictionary<IntPtr, EffectParameter>(new IntPtrBoxlessComparer());

		/* Texture-type parameters and the sampler slot (FEB register index)
		 * they bind to, applied to GraphicsDevice.Textures on Apply.
		 */
		private struct TextureBinding
		{
			public EffectParameter Parameter;
			public int SamplerSlot;

			public TextureBinding(EffectParameter parameter, int samplerSlot)
			{
				Parameter = parameter;
				SamplerSlot = samplerSlot;
			}
		}
		private List<TextureBinding> textureBindings = new List<TextureBinding>();

		private class IntPtrBoxlessComparer : IEqualityComparer<IntPtr>
		{
			public bool Equals(IntPtr x, IntPtr y)
			{
				return x == y;
			}

			public int GetHashCode(IntPtr obj)
			{
				return obj.GetHashCode();
			}
		}

		#endregion

		#region Private Static Variables

		/* Maps FNA3D_EffectParamType enum to EffectParameterType.
		 * Values match the C enum in FNA3D.h: FLOAT=0, FLOAT2=1, ..., TEXTURECUBE=12.
		 */
		private static readonly EffectParameterType[] FEBTypeMap = new EffectParameterType[]
		{
			EffectParameterType.Single,		// FNA3D_EFFECTPARAM_FLOAT
			EffectParameterType.Single,		// FNA3D_EFFECTPARAM_FLOAT2
			EffectParameterType.Single,		// FNA3D_EFFECTPARAM_FLOAT3
			EffectParameterType.Single,		// FNA3D_EFFECTPARAM_FLOAT4
			EffectParameterType.Int32,		// FNA3D_EFFECTPARAM_INT
			EffectParameterType.Bool,		// FNA3D_EFFECTPARAM_BOOL
			EffectParameterType.Single,		// FNA3D_EFFECTPARAM_MATRIX
			EffectParameterType.Texture,		// FNA3D_EFFECTPARAM_TEXTURE
			EffectParameterType.Texture1D,		// FNA3D_EFFECTPARAM_TEXTURE1D
			EffectParameterType.Texture2D,		// FNA3D_EFFECTPARAM_TEXTURE2D
			EffectParameterType.Texture3D,		// FNA3D_EFFECTPARAM_TEXTURE3D
			EffectParameterType.TextureCube		// FNA3D_EFFECTPARAM_TEXTURECUBE
		};

		private static readonly EffectParameterClass[] FEBClassMap = new EffectParameterClass[]
		{
			EffectParameterClass.Scalar,	// FLOAT
			EffectParameterClass.Vector,	// FLOAT2
			EffectParameterClass.Vector,	// FLOAT3
			EffectParameterClass.Vector,	// FLOAT4
			EffectParameterClass.Scalar,	// INT
			EffectParameterClass.Scalar,	// BOOL
			EffectParameterClass.Matrix,	// MATRIX
			EffectParameterClass.Object,	// TEXTURE
			EffectParameterClass.Object,	// TEXTURE1D
			EffectParameterClass.Object,	// TEXTURE2D
			EffectParameterClass.Object,	// TEXTURE3D
			EffectParameterClass.Object	// TEXTURECUBE
		};

		private static readonly int[] FEBRowCount = new int[]
		{
			1,	// FLOAT
			1,	// FLOAT2
			1,	// FLOAT3
			1,	// FLOAT4
			1,	// INT
			1,	// BOOL
			4,	// MATRIX (4x4)
			0,	// TEXTURE
			0,	// TEXTURE1D
			0,	// TEXTURE2D
			0,	// TEXTURE3D
			0	// TEXTURECUBE
		};

		private static readonly int[] FEBColumnCount = new int[]
		{
			1,	// FLOAT
			2,	// FLOAT2
			3,	// FLOAT3
			4,	// FLOAT4
			1,	// INT
			1,	// BOOL
			4,	// MATRIX (4x4)
			0,	// TEXTURE
			0,	// TEXTURE1D
			0,	// TEXTURE2D
			0,	// TEXTURE3D
			0	// TEXTURECUBE
		};

		/* Compute the byte size of a parameter type's value.
		 * Matches FNA3D_GetParamSize in FNA3D_Effect.h.
		 */
		private static uint FEBParamSizeBytes(FNA3D.FNA3D_EffectParamType type)
		{
			switch (type)
			{
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_FLOAT:   return 4;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_FLOAT2:  return 8;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_FLOAT3:  return 12;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_FLOAT4:  return 16;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_INT:     return 4;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_BOOL:    return 4;
				case FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_MATRIX:  return 64;
				default: return 0; /* textures have no value buffer */
			}
		}

		#endregion

		#region Public Constructor

		public Effect(GraphicsDevice graphicsDevice, byte[] effectCode)
		{
			GraphicsDevice = graphicsDevice;

			// Send the FEB blob to FNA3D_HLSL to be parsed/compiled
			FNA3D.FNA3D_CreateEffect(
				graphicsDevice.GLDevice,
				effectCode,
				effectCode.Length,
				out glEffect
			);

			// Parse effect metadata using the introspection API
			INTERNAL_parseEffect();

			// The default technique is the first technique.
			CurrentTechnique = Techniques[0];
		}

		#endregion

		#region Protected Constructor

		protected Effect(Effect cloneSource)
		{
			GraphicsDevice = cloneSource.GraphicsDevice;

			// Clone the effect via FNA3D_HLSL
			FNA3D.FNA3D_CloneEffect(
				GraphicsDevice.GLDevice,
				cloneSource.glEffect,
				out glEffect
			);

			// Parse the cloned effect's metadata
			INTERNAL_parseEffect();

			// Copy parameter values (XNA clone semantics), plus textures
			for (int i = 0; i < cloneSource.Parameters.Count; i += 1)
			{
				EffectParameter src = cloneSource.Parameters[i];
				EffectParameter dst = Parameters[i];
				if (src.values != IntPtr.Zero &&
					dst.values != IntPtr.Zero &&
					src.valuesSizeBytes > 0)
				{
					unsafe
					{
						Buffer.MemoryCopy(
							(void*) src.values,
							(void*) dst.values,
							dst.valuesSizeBytes,
							Math.Min(src.valuesSizeBytes, dst.valuesSizeBytes)
						);
					}
				}
				dst.texture = src.texture;
			}

			// The default technique is whatever the current technique was.
			for (int i = 0; i < cloneSource.Techniques.Count; i += 1)
			{
				if (cloneSource.Techniques[i] == cloneSource.CurrentTechnique)
				{
					CurrentTechnique = Techniques[i];
				}
			}
		}

		#endregion

		#region Public Methods

		public virtual Effect Clone()
		{
			return new Effect(this);
		}

		#endregion

		#region Protected Methods

		protected override void Dispose(bool disposing)
		{
			if (!IsDisposed)
			{
				IntPtr toDispose = Interlocked.Exchange(ref glEffect, IntPtr.Zero);
				if (toDispose != IntPtr.Zero)
				{
					FNA3D.FNA3D_AddDisposeEffect(
						GraphicsDevice.GLDevice,
						toDispose
					);
				}
			}
			base.Dispose(disposing);
		}

		protected internal virtual void OnApply()
		{
			// Commit all parameter values to native before applying the effect
			INTERNAL_commitParameters();
		}

		#endregion

		#region Internal Methods

		internal unsafe void INTERNAL_applyEffect(uint pass)
		{
			/* Commit parameter values to native BEFORE ApplyEffect.
			 * This must happen here rather than in OnApply() because
			 * stock effects override OnApply() to set per-frame
			 * parameters, and those values must reach the native layer
			 * before the GPU draw call.
			 */
			INTERNAL_commitParameters();

			/* Bind texture parameters to the device sampler slots.
			 * FNA3D_HLSL returns no sampler state changes from ApplyEffect,
			 * so the C# layer applies effect textures itself. Null textures
			 * are skipped — the shader path that samples them is disabled
			 * via ShaderIndex in that case.
			 */
			for (int i = 0; i < textureBindings.Count; i += 1)
			{
				TextureBinding binding = textureBindings[i];
				if (binding.Parameter.texture != null)
				{
					GraphicsDevice.Textures[binding.SamplerSlot] =
						binding.Parameter.texture;
				}
			}

			FNA3D.FNA3D_ApplyEffect(
				GraphicsDevice.GLDevice,
				glEffect,
				pass,
				GraphicsDevice.effectStateChangesPtr
			);
			/* FNA3D_HLSL state changes are always empty —
			 * render states (blend, depth, cull, etc.) are set
			 * directly by the stock effect C# classes via
			 * GraphicsDevice properties.
			 */
		}

		internal static EffectParameterCollection INTERNAL_readEffectParameterStructureMembers(
			EffectParameter parameter,
			IntPtr _type,
			Effect outer
		) {
			/* FNA3D_HLSL flattens struct parameters — each member
			 * is its own top-level parameter. Struct member info
			 * is not available in the FEB format.
			 */
			return new EffectParameterCollection(new List<EffectParameter>(0));
		}

		#endregion

		#region Private Methods

		private unsafe void INTERNAL_parseEffect()
		{
			// Set up Parameters
			int paramCount = FNA3D.FNA3D_GetEffectParamCount(glEffect);
			List<EffectParameter> parameters = new List<EffectParameter>(paramCount);
			for (int i = 0; i < paramCount; i += 1)
			{
				IntPtr paramPtr = FNA3D.FNA3D_GetEffectParam(glEffect, i);
				FNA3D.FNA3D_EffectParamType paramType = FNA3D.FNA3D_GetParamType(paramPtr);
				int typeIndex = (int) paramType;

				string paramName = Marshal.PtrToStringAnsi(
					FNA3D.FNA3D_GetParamName(paramPtr)
				);
				string paramSemantic = Marshal.PtrToStringAnsi(
					FNA3D.FNA3D_GetParamSemantic(paramPtr)
				);

				uint valueSize = FEBParamSizeBytes(paramType);

				// Allocate local value buffer, zero-initialized.
				/* Convention: the C# Effect class is the source of truth
				 * for parameter defaults — it must explicitly set every
				 * parameter its shader reads. The buffer is zeroed so
				 * unset parameters behave deterministically instead of
				 * committing uninitialized memory to the native layer.
				 */
				IntPtr values = IntPtr.Zero;
				if (valueSize > 0)
				{
					values = System.Runtime.InteropServices.Marshal.AllocHGlobal(
						(int) valueSize
					);
					unsafe
					{
						byte* ptr = (byte*) values;
						for (uint b = 0; b < valueSize; b += 1)
						{
							ptr[b] = 0;
						}
					}
				}

				// Create the parameter (without mojoType)
				EffectParameter toAdd = new EffectParameter(
					paramName,
					paramSemantic ?? string.Empty,
					FEBRowCount[typeIndex],
					FEBColumnCount[typeIndex],
					0, /* elementCount — FEB doesn't track arrays */
					FEBClassMap[typeIndex],
					FEBTypeMap[typeIndex],
					EffectAnnotationCollection.Empty, /* FEB has no annotations */
					values,
					valueSize,
					this,
					paramPtr /* FNA3D_EffectParam* */
				);

				parameters.Add(toAdd);

				/* Track texture parameters so INTERNAL_applyEffect can
				 * bind them to the device sampler slots — FNA3D_HLSL
				 * state changes are always empty, so the C# layer is
				 * responsible for this. The FEB register index is the
				 * t# sampler slot.
				 */
				if (paramType >= FNA3D.FNA3D_EffectParamType.FNA3D_EFFECTPARAM_TEXTURE)
				{
					textureBindings.Add(new TextureBinding(
						toAdd,
						(int) FNA3D.FNA3D_GetParamRegisterIndex(paramPtr)
					));
				}
			}
			Parameters = new EffectParameterCollection(parameters);

			// Set up Techniques
			int techCount = FNA3D.FNA3D_GetEffectTechniqueCount(glEffect);
			List<EffectTechnique> techniques = new List<EffectTechnique>(techCount);
			uint globalPassCounter = 0;
			for (int i = 0; i < techCount; i += 1)
			{
				IntPtr techPtr = FNA3D.FNA3D_GetEffectTechnique(glEffect, i);
				string techName = Marshal.PtrToStringAnsi(
					FNA3D.FNA3D_GetTechniqueName(techPtr)
				);
				int passCount = FNA3D.FNA3D_GetTechniquePassCount(techPtr);

				// Set up Passes
				EffectPassCollection passes;
				if (passCount == 1)
				{
					passes = new EffectPassCollection(
						new EffectPass(
							Marshal.PtrToStringAnsi(
								FNA3D.FNA3D_GetPassName(techPtr, 0)
							),
							EffectAnnotationCollection.Empty,
							this,
							techPtr,
							0,
							globalPassCounter
						)
					);
					globalPassCounter++;
				}
				else
				{
					List<EffectPass> passList = new List<EffectPass>(passCount);
					for (int j = 0; j < passCount; j += 1)
					{
						passList.Add(new EffectPass(
							Marshal.PtrToStringAnsi(
								FNA3D.FNA3D_GetPassName(techPtr, j)
							),
							EffectAnnotationCollection.Empty,
							this,
							techPtr,
							(uint) j,
							globalPassCounter
						));
						globalPassCounter++;
					}
					passes = new EffectPassCollection(passList);
				}

				techniques.Add(new EffectTechnique(
					techName,
					techPtr,
					passes,
					EffectAnnotationCollection.Empty
				));
			}
			Techniques = new EffectTechniqueCollection(techniques);
		}

		private void INTERNAL_commitParameters()
		{
			/* Push all parameter values to the native layer before ApplyEffect.
			 * This ensures per-frame values (matrices, colors, etc.) set by stock
			 * effects are committed to the GPU uniform buffer.
			 */
			for (int i = 0; i < Parameters.Count; i += 1)
			{
				Parameters[i].CommitToNative();
			}
		}

		#endregion
	}
}
