Shader "CrossSection/Others/CapPrepare" {

	Properties{
		_StencilMask("Stencil Mask", Range(0, 255)) = 0
		[Enum(None,0,Alpha,1,Red,8,Green,4,Blue,2,RGB,14,RGBA,15)] _ColorMask("Color Mask", Int) = 0
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilOpFront("Stencil Operation Front", Int) = 1//Zero
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilOpBack("Stencil Operation Back", Int) = 2//Replace
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Int) = 0
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Int) = 4
		[Toggle(RETRACT_BACKFACES)] _retractBackfaces("retractBackfaces", Float) = 0
	}


    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		//ZWrite off
		ColorMask[_ColorMask]
        Stencil {
			Ref[_StencilMask]
			CompBack Always
			PassBack [_StencilOpBack]

			CompFront Always
			PassFront [_StencilOpFront]
        }
		
		Pass {
			Cull [_Cull]
			ColorMask[_ColorMask]
			ZTest[_ZTest]
			//ZWrite On
			CGPROGRAM
			#include "CGIncludes/section_clipping_CS.cginc"
			#pragma multi_compile __ CLIP_PLANE CLIP_PIE CLIP_SPHERE CLIP_CORNER CLIP_BOX CLIP_CUBOID
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}

        CGINCLUDE
		#include "CGIncludes/section_clipping_CS.cginc"
		float4 _Color;
            struct appdata {
                float4 vertex : POSITION;
            };
            struct v2f {
                float4 pos : SV_POSITION;
				float3 wpos: TEXCOORD0;
            };

			half _BackfaceExtrusion;

            v2f vert(appdata v) 
			{
				float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
#ifdef RETRACT_BACKFACES
				float3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				float dotProduct = dot(v.normal, viewDir);
				if (dotProduct < 0) {
					float3 worldNorm = UnityObjectToWorldNormal(v.normal);
					worldPos -= worldNorm * _BackfaceExtrusion;
					v.vertex.xyz = mul(unity_WorldToObject, float4(worldPos, 1)).xyz;
				}
#endif

				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.wpos = worldPos;
				return o;
            }
            half4 frag(v2f i) : SV_Target {
			#if CLIP_BOX||CLIP_PIE
				SECTION_INTERSECT(i.wpos);
			#else
				SECTION_CLIP(i.wpos);
			#endif
				return half4(1,1,1,1);
            }
        ENDCG

    } 
}