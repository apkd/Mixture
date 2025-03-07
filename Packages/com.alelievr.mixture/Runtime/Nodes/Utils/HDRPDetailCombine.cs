using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GraphProcessor;
using System.Linq;

namespace Mixture
{
	[Documentation(@"
Generates an HDRP detail map by combining the desaturated albedo, normal and smoothness maps.
See [HDRP Detail Map Documentation](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@latest/index.html?subfolder=/manual/Mask-Map-and-Detail-Map.html for more information)
")]

	[System.Serializable, NodeMenuItem("Operators/Detail Combine (HDRP)")]
	public class HDRPDetailCombine : FixedShaderNode
	{
		public override string name => "Detail Combine (HDRP)";

		public override string shaderName => "Hidden/Mixture/HDRPDetailCombine";

		public override bool displayMaterialInspector => true;

		// Enumerate the list of material properties that you don't want to be turned into a connectable port.
		protected override IEnumerable<string> filteredOutProperties => new string[]{};

		protected override MixtureRTSettings defaultRTSettings => Get2DOnlyRTSettings(base.defaultRTSettings);

		// Override this if you node is not compatible with all dimensions
		public override List<OutputDimension> supportedDimensions => new List<OutputDimension>() {
			OutputDimension.Texture2D,
			OutputDimension.Texture3D,
			OutputDimension.CubeMap,
		};
	}
}