// Based on Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "CrossSection/Standard/Box" 
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
		[Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		_MetallicGlossMap("Metallic", 2D) = "white" {}

		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

		_BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		_ParallaxMap ("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}
		
		_DetailMask("Detail Mask", 2D) = "white" {}

		_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

		[Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0

		_SectionColor ("Section Color", Color) = (1,1,1,1)
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Int) = 0  //Off
		_StencilMask("Stencil Mask", Range(0, 255)) = 255
		[HideInInspector][Toggle] _inverse("inverse", Float) = 0
		[Toggle(RETRACT_BACKFACES)] _retractBackfaces("retractBackfaces", Float) = 0

	}

	CGINCLUDE
		#define UNITY_SETUP_BRDF_INPUT MetallicSetup
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
		LOD 300

		Stencil
		{
			Ref [_StencilMask]
			CompBack Always
			PassBack Replace

			CompFront Always
			PassFront Zero
		}

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }
			Cull[_Cull] //Cull off
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target 3.0
			
			// -------------------------------------
					
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_fragment _EMISSION
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local_fragment _GLOSSYREFLECTIONS_OFF
			#pragma shader_feature_local _PARALLAXMAP
			
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog			
			#pragma multi_compile_instancing

			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_PLANE CLIP_CORNER // to get enumerated keywords as local.
			#pragma shader_feature_local RETRACT_BACKFACES
			#pragma vertex vertBase
			#pragma fragment fragBase
			#include "CGIncludes/UnityStandardCoreForward_CS.cginc"

			ENDCG
		}

		// ------------------------------------------------------------------
		// ColorMask Pass


		Pass
		{
			Name "CROSS-SECTION-HIDDEN"
			Cull Off
			ColorMask 0
			CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.
			#pragma shader_feature_local RETRACT_BACKFACES
			#include "UnityCG.cginc"
			#include "CGIncludes/section_clipping_CS.cginc"
            struct appdata {
                float4 vertex : POSITION;
            };
            struct v2f {
                float4 pos : SV_POSITION;
				float3 wpos : TEXCOORD1;
            };
            
			half _BackfaceExtrusion;

            v2f vert(appdata_full v) {

			#ifdef RETRACT_BACKFACES
				float3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				float dotProduct = dot(v.normal, viewDir);
				if(dotProduct<0) {
					float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
					float3 worldNorm = UnityObjectToWorldNormal(v.normal);
					worldPos -= worldNorm * _BackfaceExtrusion;
					v.vertex.xyz = mul(unity_WorldToObject, float4(worldPos, 1)).xyz;
				}
			#endif
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
				float3 worldPos = mul (unity_ObjectToWorld, v.vertex).xyz;
				o.wpos = worldPos;
                return o;
            }
            half4 frag(v2f i) : SV_Target {
			#if CLIP_BOX
				SECTION_INTERSECT(i.wpos);
			#endif
			#if CLIP_CORNER
				SECTION_CLIP(i.wpos);
			#endif
                return half4(1,1,1,1);
            }
            ENDCG

		}

		// ------------------------------------------------------------------
		//  Additive forward pass (one light per pass)
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One
			Fog { Color (0,0,0,0) } // in additive pass fog should be black
			ZWrite Off
			ZTest LEqual

			CGPROGRAM
			#pragma target 3.0

			// -------------------------------------
		
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			#pragma shader_feature_local _PARALLAXMAP
			
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.
			#pragma vertex vertAdd
			#pragma fragment fragAdd

			#include "CGIncludes/UnityStandardCoreForward_CS.cginc"

			ENDCG
		}
		// ------------------------------------------------------------------
		//  Shadow rendering pass
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			Cull[_Cull] //Cull off
			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma target 3.0
			
			// -------------------------------------

			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local _PARALLAXMAP
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma vertex vertShadowCasterClip
			#pragma fragment fragShadowCasterClip

			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.
			#include "CGIncludes/UnityStandardShadow_CS.cginc"

			ENDCG
		}
		// ------------------------------------------------------------------
		//  Deferred pass
		Pass
		{
			Name "DEFERRED"
			Tags { "LightMode" = "Deferred" }
			Cull[_Cull] //Cull off
			CGPROGRAM
			#pragma target 3.0
			#pragma exclude_renderers nomrt
			

			// -------------------------------------

			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_fragment _EMISSION
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			#pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE
			
			#pragma vertex vertDeferredClip
			#pragma fragment fragDeferredClip

			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.
			#pragma shader_feature_local RETRACT_BACKFACES

			#include "CGIncludes/UnityStandardCore_CS.cginc"
			//#include "UnityStandardCore.cginc"

			ENDCG
		}

		// ------------------------------------------------------------------
		// Extracts information for lightmapping, GI (emission, albedo, ...)
		// This pass it not used during regular rendering.
		Pass
		{
			Name "META" 
			Tags { "LightMode"="Meta" }

			Cull Off

			CGPROGRAM
			#pragma vertex vert_meta
			#pragma fragment frag_meta

			#pragma shader_feature_fragment _EMISSION
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			#pragma shader_feature EDITOR_VISUALIZATION

			#pragma multi_compile __ CLIP_PLANE CLIP_PIE CLIP_CUBOID CLIP_BOX CLIP_SPHERE CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_PLANE CLIP_PIE CLIP_CUBOID CLIP_BOX CLIP_SPHERE CLIP_CORNER // to get enumerated keywords as local.

			//#include "UnityStandardMeta.cginc"
			#include "CGIncludes/UnityStandardMetaClip.cginc"
			ENDCG
		}
	}

	SubShader
	{
		Tags { "RenderType"="Clipping" "PerformanceChecks"="False" }
		LOD 150

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }
			Cull[_Cull] //Cull off
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target 2.0
			
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_fragment _EMISSION
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local_fragment _GLOSSYREFLECTIONS_OFF
			// SM2.0: NOT SUPPORTED shader_feature_local _DETAIL_MULX2
			// SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP

			#pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.
			#pragma vertex vertBase
			#pragma fragment fragBase
			#include "CGIncludes/UnityStandardCoreForward_CS.cginc"

			ENDCG
		}
		// ------------------------------------------------------------------
		//  Additive forward pass (one light per pass)
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			
			Blend [_SrcBlend] One
			Fog { Color (0,0,0,0) } // in additive pass fog should be black
			ZWrite Off
			ZTest LEqual
			
			CGPROGRAM
			#pragma target 2.0

			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			// SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP
			#pragma skip_variants SHADOWS_SOFT
			
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			
			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.

			#pragma vertex vertAdd
			#pragma fragment fragAdd
			#include "CGIncludes/UnityStandardCoreForward_CS.cginc"

			ENDCG
		}
		// ------------------------------------------------------------------
		//  Shadow rendering pass
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			Cull[_Cull] //Cull off
			
			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma target 2.0

            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma skip_variants SHADOWS_SOFT
            #pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCasterClip
			#pragma fragment fragShadowCasterClip

			#pragma multi_compile __ CLIP_BOX CLIP_CORNER
			//#pragma multi_compile_local __ CLIP_BOX CLIP_CORNER // to get enumerated keywords as local.

			#include "CGIncludes/UnityStandardShadow_CS.cginc"

			ENDCG
		}

		// ------------------------------------------------------------------
		// Extracts information for lightmapping, GI (emission, albedo, ...)
		// This pass it not used during regular rendering.
		Pass
		{
			Name "META" 
			Tags { "LightMode"="Meta" }

			Cull Off

			CGPROGRAM
			#pragma vertex vert_meta
			#pragma fragment frag_meta

			#pragma shader_feature_fragment _EMISSION
			#pragma shader_feature_local _METALLICGLOSSMAP
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local_fragment _DETAIL_MULX2
			#pragma shader_feature EDITOR_VISUALIZATION
			#pragma multi_compile __ CLIP_PLANE CLIP_PIE CLIP_CUBOID CLIP_BOX CLIP_SPHERE
			//#pragma multi_compile_local __ CLIP_PLANE CLIP_PIE CLIP_CUBOID CLIP_BOX CLIP_SPHERE // to get enumerated keywords as local.

			//#include "UnityStandardMeta.cginc"
			#include "CGIncludes/UnityStandardMetaClip.cginc"
			ENDCG
		}
	}

	FallBack "VertexLit"
	CustomEditor "CrossSectionStandardShaderGUI"
}
