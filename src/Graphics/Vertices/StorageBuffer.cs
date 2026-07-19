using System;
using System.Runtime.InteropServices;
using Microsoft.Xna.Framework.Graphics;

namespace Microsoft.Xna.Framework.Graphics
{
	/// <summary>
	/// GPU buffer accessible from shaders as StructuredBuffer / RWStructuredBuffer.
	/// Supports vertex shader read and optional vertex shader write.
	/// </summary>
	public class StorageBuffer : GraphicsResource
	{
		internal IntPtr buffer;
		private readonly int sizeInBytes;

		/// <summary>
		/// Creates a storage buffer for shader access.
		/// </summary>
		/// <param name="graphicsDevice">The GraphicsDevice.</param>
		/// <param name="sizeInBytes">Size of the buffer in bytes.</param>
		/// <param name="vertexWrite">If true, vertex shaders can write to this buffer
		/// (requires vertexPipelineStoresAndAtomics Vulkan feature).</param>
		/// <param name="vertexRead">If true, vertex shaders can read from this buffer.</param>
		public StorageBuffer(
			GraphicsDevice graphicsDevice,
			int sizeInBytes,
			bool vertexWrite,
			bool vertexRead
		) {
			GraphicsDevice = graphicsDevice;
			this.sizeInBytes = sizeInBytes;

			buffer = FNA3D.FNA3D_GenStorageBuffer(
				GraphicsDevice.GLDevice,
				sizeInBytes,
				(byte) (vertexWrite ? 1 : 0),
				(byte) (vertexRead ? 1 : 0)
			);
		}

		public int SizeInBytes
		{
			get { return sizeInBytes; }
		}

		protected override void Dispose(bool disposing)
		{
			if (!IsDisposed)
			{
				IntPtr toDispose = System.Threading.Interlocked.Exchange(
					ref buffer, IntPtr.Zero
				);
				if (toDispose != IntPtr.Zero)
				{
					FNA3D.FNA3D_AddDisposeStorageBuffer(
						GraphicsDevice.GLDevice,
						toDispose
					);
				}
			}
			base.Dispose(disposing);
		}

		public unsafe void SetData<T>(T[] data) where T : struct
		{
			SetData(0, data, 0, data.Length);
		}

		public unsafe void SetData<T>(
			int offsetInBytes,
			T[] data,
			int startIndex,
			int elementCount
		) where T : struct
		{
			int elementSizeInBytes = Marshal.SizeOf(typeof(T));
			int dataLength = elementCount * elementSizeInBytes;

			GCHandle handle = GCHandle.Alloc(data, GCHandleType.Pinned);
			FNA3D.FNA3D_SetStorageBufferData(
				GraphicsDevice.GLDevice,
				buffer,
				offsetInBytes,
				(IntPtr) (handle.AddrOfPinnedObject().ToInt64() +
					startIndex * elementSizeInBytes),
				dataLength
			);
			handle.Free();
		}

		public unsafe void GetData<T>(T[] data) where T : struct
		{
			GetData(0, data, 0, data.Length);
		}

		public unsafe void GetData<T>(
			int offsetInBytes,
			T[] data,
			int startIndex,
			int elementCount
		) where T : struct
		{
			int elementSizeInBytes = Marshal.SizeOf(typeof(T));
			int dataLength = elementCount * elementSizeInBytes;

			GCHandle handle = GCHandle.Alloc(data, GCHandleType.Pinned);
			FNA3D.FNA3D_GetStorageBufferData(
				GraphicsDevice.GLDevice,
				buffer,
				offsetInBytes,
				(IntPtr) (handle.AddrOfPinnedObject().ToInt64() +
					startIndex * elementSizeInBytes),
				dataLength
			);
			handle.Free();
		}
	}
}
