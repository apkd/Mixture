Shader "Hidden/Mixture/Levels"
{
    Properties
	{
		[InlineTexture]_Input_2D("Input", 2D) = "black" {}
		[InlineTexture]_Input_3D("Input", 3D) = "black" {}
		[InlineTexture]_Input_Cube("Input", Cube) = "black" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			HLSLPROGRAM
			#include "Packages/com.alelievr.mixture/Runtime/Shaders/MixtureFixed.hlsl"
            #include "Packages/com.alelievr.mixture/Editor/Resources/HistogramData.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #pragma vertex CustomRenderTextureVertexShader
			#pragma fragment MixtureFragment
			#pragma target 5.0

			// The list of defines that will be active when processing the node with a certain dimension
            #pragma shader_feature CRT_2D CRT_3D CRT_CUBE
            #pragma enable_d3d11_debug_symbols

            TEXTURE_X(_Input);

            Texture2D<float> _InterpolationCurve;
            float3 _RcpTextureSize;

            StructuredBuffer<LuminanceData> _Luminance;

            float _Mode;
            float _ManualMin;
            float _ManualMax;

            void GetLuminanceRemapValues(out float minLuminace, out float maxLuminance)
            {
                if (_Mode == 0) // Manual
                {
                    minLuminace = _ManualMin;
                    maxLuminance = _ManualMax;
                }
                else // Authomatic
                {
                    minLuminace = _Luminance[0].minLuminance;
                    maxLuminance = _Luminance[0].maxLuminance;
                }
            }

            void GetTextureAbsoluteLuminanceValues(out float minLuminace, out float maxLuminance)
            {
                minLuminace = _Luminance[0].minLuminance;
                maxLuminance = _Luminance[0].maxLuminance;
            }

			float4 mixture (v2f_customrendertexture i) : SV_Target
			{
                // TODO: function to turn the id into direction / uv for cube / 3D
                float3 uv = GetDefaultUVs(i);
                uv += _RcpTextureSize * 0.5;
                float4 input = SAMPLE_X_NEAREST_CLAMP(_Input, uv, uv);

                float minRemapLum, maxRemapLum;
                GetLuminanceRemapValues(minRemapLum, maxRemapLum);

                float minAbsoluteLum, maxAbsoluteLum;
                GetTextureAbsoluteLuminanceValues(minAbsoluteLum, maxAbsoluteLum);

                float totalMinLum = (minRemapLum - minAbsoluteLum) / (maxRemapLum - minRemapLum);
                float totalMaxLum = (maxRemapLum) / (maxRemapLum - minRemapLum);

                input.rgb -= minRemapLum;
                input.rgb /= (maxRemapLum - minRemapLum);

                // remap luminance between 0 and 1 to sample the curve:
                float clampedLuminance = clamp(Luminance(input.rgb), totalMinLum, totalMaxLum);
                // TODO: this 01 remap doesn't work because totalMinLum and totalMaxLum aren't the min and max lum of the iamge in manual mode
                float luminance01 = (clampedLuminance - totalMinLum) * rcp(totalMaxLum - totalMinLum);

                // Remap luminance with curve
                float t = luminance01;
                luminance01 = _InterpolationCurve.SampleLevel(s_linear_clamp_sampler, luminance01, 0).r;

                // Remap luminance between min and max
                float correctedLuminance = luminance01 * (totalMaxLum - totalMinLum) + totalMinLum;
                // Correct the color with the new luminance
                float luminanceOffset = correctedLuminance - clampedLuminance;
                // float3 D65 = float3(0.2126729, 0.7151522, 0.0721750);

                input.rgb *= 1 + luminanceOffset;

                float4 color = luminanceOffset; //saturate(1 - abs(3 * luminance01 / 3 - float4(0, 1, 2, 3)));

                return input;
			}
			ENDHLSL
		}
	}
}