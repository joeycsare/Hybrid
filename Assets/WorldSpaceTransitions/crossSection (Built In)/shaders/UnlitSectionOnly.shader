Shader "CrossSection/UnlitSectionOnly"
{
    Properties
    {
		_SectionColor("Section Color", Color) = (0.5,0.5,0.5,1)
		[Enum(None,0,Alpha,1,Red,8,Green,4,Blue,2,RGB,14,RGBA,15)] _ColorMask("Color Mask", Int) = 15
		_StencilMask("Stencil Mask", Range(0, 255)) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Clipping"  "Queue" = "Geometry+1" }
        LOD 100
		
        Pass
		
        {
			ColorMask[_ColorMask]
			Cull Off
			Stencil
			{
				Ref[_StencilMask]
				Comp Always
				PassBack Replace
				PassFront Zero
			}

			CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
			#pragma multi_compile __ CLIP_PLANE

            #include "UnityCG.cginc"
			#include "CGIncludes/section_clipping_CS.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
				float4 wpos : TEXCOORD1;
                UNITY_FOG_COORDS(0)
                float4 vertex : SV_POSITION;
            };

			fixed4 _SectionColor;
#if			CLIP_PLANE
			static const bool _frontSide = (dot(_WorldSpaceCameraPos - _SectionPoint, _SectionPlane) > 0);
#endif
            v2f vert (appdata v)
            {
                v2f o;
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wpos = mul(unity_ObjectToWorld, v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				//SECTION_CLIP(i.wpos.xyz);
#if			CLIP_PLANE
				if (ClipBool(i.wpos.xyz)== _frontSide) discard;
#endif
				fixed4 col = _SectionColor;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
