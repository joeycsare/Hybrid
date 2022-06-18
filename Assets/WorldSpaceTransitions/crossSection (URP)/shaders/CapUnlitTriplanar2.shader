Shader "CrossSectionURP/CapUnlit/HatchTriplanar2"
{
    Properties
    {
        _BaseMap("Texture", 2D) = "white" {}
		_MapScale("TriplanarMapScale", Float) = 1
        _BaseColor("Color", Color) = (1, 1, 1, 1)
        //_Cutoff("AlphaCutout", Range(0.0, 1.0)) = 0.5

        // BlendMode
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("Src", Float) = 1.0
        [HideInInspector] _DstBlend("Dst", Float) = 0.0
        [HideInInspector] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
        
        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
        
        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [HideInInspector] _SampleGI("SampleGI", float) = 0.0 // needed from bakedlit

		_StencilMask("Stencil Mask", Range(0, 255)) = 255
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent+1"}
        LOD 100

		Stencil{
			Ref [_StencilMask]
			Comp Equal
			Pass Zero
		}

        Blend [_SrcBlend][_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        Pass
        {
            Name "Unlit"
            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            //#pragma multi_compile_instancing

            #include "UnlitInput.hlsl"

			uniform float4x4 _WorldToObjectMatrix;
			//static const float3x3 projMatrix = float3x3(_SectionDirX.xyz, _SectionDirY.xyz, _SectionDirZ.xyz);
			static const float3x3 projMatrix = float3x3(_WorldToObjectMatrix[0].xyz, _WorldToObjectMatrix[1].xyz, _WorldToObjectMatrix[2].xyz);

			//float _MapScale;

            struct Attributes
            {
                float4 positionOS       : POSITION;
				float3 normalOS			: NORMAL;
				float4 tangentOS		: TANGENT;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv        : TEXCOORD0;
                float fogCoord  : TEXCOORD1;
				float3 positionWS : TEXCOORD2;
				half3 normalWS    : TEXCOORD3;
				//float3 localCoord : TEXCOORD4;
				//half3 localNormal    : TEXCOORD5;

                float4 vertex : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                output.positionWS = vertexInput.positionWS;
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
				output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				half2 UV;

				float3 projPos = mul(projMatrix, input.positionWS);
				float3 projNorm = mul(projMatrix, input.normalWS);

				//if(abs(projNorm.x)>abs(projNorm.y)&&abs(projNorm.x)>abs(projNorm.z))
				//{
					UV = projPos.zy * _MapScale; // side
					half4 cx = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, float2(UV.x*_BaseMap_ST.x, UV.y*_BaseMap_ST.y))*abs(projNorm.x); // use WALLSIDE texture
				//}
				//else if(abs(projNorm.z)>abs(projNorm.y)&&abs(projNorm.z)>abs(projNorm.x))
				//{
					UV = projPos.xy * _MapScale; // front
					half4 cz = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, float2(UV.x*_BaseMap_ST.x, UV.y*_BaseMap_ST.y))*abs(projNorm.z); // use WALL texture
				//}
				//else
				//{
					UV = projPos.xz * _MapScale; // top
					half4 cy = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, float2(UV.x*_BaseMap_ST.x, UV.y*_BaseMap_ST.y))*abs(projNorm.y); // use FLR texture
				//}

				half4 color = (cx + cy + cz) * _BaseColor;

#ifdef _ALPHAPREMULTIPLY_ON
                color *= alpha;
#endif

                color.rgb = MixFog(color.rgb, input.fogCoord);

                return color;
            }
            ENDHLSL
        }
        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            //#pragma multi_compile_instancing

            #include "UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaUnlit

            #include "UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitMetaPass.hlsl"

            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
    //CustomEditor "UnityEditor.CrossSection.URP.ShaderGUI.UnlitShader"
}
