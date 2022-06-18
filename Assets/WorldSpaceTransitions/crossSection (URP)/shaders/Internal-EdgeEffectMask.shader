// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/CrossSection/EdgeEffectMask" {

SubShader {
	Tags { "RenderType"="Clipping" }
	
	Pass {
	Cull Off
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#pragma multi_compile __ CLIP_PLANE CLIP_PIE CLIP_SPHERE CLIP_CUBOID CLIP_CORNER CLIP_TUBES
uniform half _inverse = 0;
#include "section_clipping_CS.cginc"
#include "UnityCG.cginc"

// Properties
sampler2D_float _CameraDepthNormalsTexture;

static const half4 _ColorFront = half4(1, 0, 0, 1);
static const half4 _ColorBack = half4(0, 1, 0, 1);

struct v2f {
    float4 pos : SV_POSITION;
	float4 wpos : TEXCOORD3;
	float linearDepth : TEXCOORD2;
	float4 screenPos : TEXCOORD1;
	float3 texCoord : TEXCOORD0;
	UNITY_VERTEX_OUTPUT_STEREO
};
v2f vert( appdata_base v ) {
    v2f o;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	float3 worldPos = mul(unity_ObjectToWorld, float4(v.vertex)).xyz;
	o.wpos = float4(worldPos.xyz, 1);
    o.pos = UnityObjectToClipPos(v.vertex);
	o.texCoord = v.texcoord;
	o.screenPos = ComputeScreenPos(o.pos);
	o.linearDepth = -(UnityObjectToViewPos(v.vertex).z * _ProjectionParams.w);
    return o;
}
half4 frag(v2f i, float face : VFACE) : SV_Target{
	SECTION_CLIP(i.wpos);
	half4 c = half4(0, 0, 0, 1);
	// decode depth texture info
	float2 uv = i.screenPos.xy / i.screenPos.w; // normalized screen-space pos
	//float camDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthNormalsTexture, uv);
	float4 enc = tex2D(_CameraDepthNormalsTexture, uv);
	float camDepth = DecodeFloatRG(enc.zw);
	//camDepth = Linear01Depth (camDepth); // converts z buffer value to depth value from 0..1
	float diff = saturate(i.linearDepth - camDepth);
	if (diff < 0.003)
		c = face > 0 ? _ColorFront : _ColorBack;

	return c;
}
ENDCG
	}
}





Fallback Off
}
