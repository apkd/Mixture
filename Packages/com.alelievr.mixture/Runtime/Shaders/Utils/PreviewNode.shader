Shader "Hidden/Mixture/PreviewNode"
{	
	Properties
	{
		// By default a shader node is supposed to handle all the input texture dimension, we use a prefix to determine which one is used
		[InlineTexture]_Source_2D("Source", 2D) = "white" {}
		[InlineTexture]_Source_3D("Source", 3D) = "white" {}
		[InlineTexture]_Source_Cube("Source", Cube) = "white" {}

		// Other parameters
		[Enum(Color, 0, Normal, 1, Heightmap, 2)]_Mode("Mode", Int) = 0

		[VisibleIf(_Mode, 0)]_ColorMin("Min Remap Color", Vector) = (0, 0, 0, 0)
		[VisibleIf(_Mode, 0)]_ColorMax("Max Remap Color", Vector) = (1, 1, 1, 1)
		[VisibleIf(_Mode, 0)][Toggle]_Gamma("Gamma", Float) = 0 

		[VisibleIf(_Mode, 1)][Enum(Tangent Space, 0, Object Space, 1, Lighting, 2)]_NormalMode("Normal Mode", Float) = 0
		[VisibleIf(_Mode, 1)][MixtureVector3]_LightPosition("Light Position", Vector) = (0, 0, 0.2, 0)

		[VisibleIf(_Mode, 2)][Enum(Altitude, 0, Heat, 1)]_HeightColorSet("Color Set", Float) = 0
		[VisibleIf(_Mode, 2)][Enum(R, 0, G, 1, B, 2, A, 3)]_HeightChannel("Channel", Float) = 0
		[VisibleIf(_Mode, 2)]_HeightMin("Min", Float) = 0
		[VisibleIf(_Mode, 2)]_HeightMax("Max", Float) = 1

		_Tiling("Tiling", Range(1, 3)) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			HLSLPROGRAM
			#include "Packages/com.alelievr.mixture/Runtime/Shaders/MixtureFixed.hlsl"
			#include "Packages/com.alelievr.mixture/Runtime/Shaders/MixtureSRGB.hlsl"
            #pragma vertex CustomRenderTextureVertexShader
			#pragma fragment MixtureFragment

			#pragma target 3.0

			// The list of defines that will be active when processing the node with a certain dimension
            #pragma shader_feature CRT_2D CRT_3D CRT_CUBE

			// This macro will declare a version for each dimention (2D, 3D and Cube)
			TEXTURE_SAMPLER_X(_Source);
			float _Mode;
			float4 _ColorMin;
			float4 _ColorMax;
			float _Gamma;
			float _SourceMip;

			float _NormalMode;
			float3 _LightPosition;

			float _HeightColorSet;
			float _HeightChannel;
			float _HeightMin;
			float _HeightMax;

			float _Tiling;

			float4 PreviewColor(float4 value)
			{
				if (_Gamma > 0)
					value.rgb = LinearToSRGB(value.rgb);

				return value / (_ColorMax - _ColorMin) + _ColorMin;
			}

			float4 PreviewNormal(float4 value, float3 uv)
			{
				switch (_NormalMode)
				{
					default:
					case 0: // Tangent Space
						break;
					case 1:
						value.rgb = normalize(value.rgb * 2 - 1);
						break;
					case 2:
						float3 pos = (uv.xyz - 0.5) * 2;
						float diffuse = dot(normalize(_LightPosition - pos), normalize(value.rgb * 2 - 1));
						value = float4(diffuse.xxx, 1);
						break;
				}

				return value;
			}

			float3 SampleHeatGradient(float value)
			{
				float3 color = lerp(0, float3(0.780, 0, 0), smoothstep(0, 0.3333, value));
				color = lerp(color, float3(1, 1, 0), smoothstep(0.3333, 0.6666, value));
				color = lerp(color, 1, smoothstep(0.6666, 1, value));

				return color;
			}

			float3 SampleAltitudeGradient(float value)
			{
				// float3 white = float3(1, 1, 1); //white 
				const float3 brown = float3(0.623, 0.364, 0.058); // brown 
				const float3 yellow = float3(0.952, 0.929, 0.086); // yellow 
				const float3 darkGreen = float3(0.023, 0.454, 0.156); // dark green 
				const float3 white = float3(1, 1, 1); //white 
				const float3 lightBlue = float3(0.639, 0.831, 1); // light blue
				const float3 blue = float3(0.113, 0.078, 0.858); // blue
				const float3 purple = float3(0.596, 0.054, 0.882); // purple

				const int colorCount = 8;
				const float3 colors[colorCount] = {
					purple,
					blue,
					lightBlue,
					white,
					darkGreen,
					yellow,
					brown,
					white,
				};

				const float weights[colorCount + 1] = {
					0.0,
					0.05,
					0.15,
					0.375,
					0.5,
					0.51,
					0.65,
					0.875,
					1.0
				};

				float3 color = purple;
				for (float i = 0; i < colorCount; i++)
					color = lerp(color, colors[i], smoothstep(weights[i], weights[i + 1], value + 0.5 / colorCount));

				// float3 color = lerp(0, white, smoothstep(0, 0.3333, value));
				// color = lerp(color, float3(1, 1, 0), smoothstep(0.3333, 0.6666, value));
				// color = lerp(color, 1, smoothstep(0.6666, 1, value));

				return color;
			}

			float4 PreviewHeightmap(float4 value)
			{
				float height = value[uint(_HeightChannel)];
				height = height / (_HeightMax - _HeightMin) + _HeightMin;
				value.a = 1;

				switch (_HeightColorSet)
				{
					default:
					case 0: // Altitude 
						value.rgb = SampleAltitudeGradient(height);
						break;
					case 1: // Heat
						value.rgb = SampleHeatGradient(height);
						break;
				}
				return value;
			}

			float4 mixture (v2f_customrendertexture i) : SV_Target
			{
				float3 uv = (i.localTexcoord.xyz - 0.5) * _Tiling + 0.5;
				float4 value = SAMPLE_LOD_X(_Source, uv, i.direction, _SourceMip);

				switch (_Mode)
				{
					default:
					case 0: // Color
						value = PreviewColor(value);
						break;
					case 1: // Normal 
						value = PreviewNormal(value, uv);
						break;
					case 2: //Heightmap 
						value = PreviewHeightmap(value);
						break;
				}

				return value;
			}
			ENDHLSL
		}
	}
}
